namespace Shell.Reflection;

using System;
using System.Collections;
using Shell.Core;

// Value storage for the properties of one object, laid out by its TypeDescriptor. Detects real changes, keeps
// per-property versions and notifies observers; the owner decides what to invalidate (see PropertyDescriptor.mInvalidates).
class PropertyStore
{
	TypeDescriptor mType;
	Value[] mValues;
	ObservableValue[] mObservables;     // created on demand
	public IPropertyChangeListener mListener;
	StringPool mStrings;
	ContributionStack[] mStacks;        // created on demand: only properties that styles / animation / ... contribute to
	bool[] mExplicit;                   // value was written by Set (authored) before any contribution existed
	Value[] mDefaults;                  // effective defaults (descriptor default + type overrides)
	public const int cAuthoredSource = 0;

	public this(TypeDescriptor type, StringPool strings = null)
	{
		mType = type;
		mStrings = strings;
		let count = type.mTotalPropertyCount;
		mValues = new Value[count];
		mObservables = new ObservableValue[count];

		let all = scope List<PropertyDescriptor>();
		type.CollectProperties(all);
		for (let property in all)
			mValues[property.mIndex] = property.mDefault;
		type.ApplyDefaultOverrides(mValues);
		mDefaults = new Value[count];
		mStacks = new ContributionStack[count];
		mExplicit = new bool[count];
		for (int i < count)
			mDefaults[i] = mValues[i];
		for (let value in mValues)
			RetainValue(value);
	}

	public ~this()
	{
		for (let value in mValues)
			ReleaseValue(value);
		for (let observable in mObservables)
			delete observable;
		delete mObservables;
		delete mValues;
		for (let stack in mStacks)
			delete stack;
		delete mStacks;
		delete mExplicit;
		delete mDefaults;
	}

	// String / enum values may point into the collectible part of the string pool. A slot that holds such a value keeps its entry alive.
	void RetainValue(Value value)
	{
		if (mStrings != null && (value.mKind == .String || value.mKind == .Enum))
			mStrings.Retain(value.mString);
	}

	void ReleaseValue(Value value)
	{
		if (mStrings != null && (value.mKind == .String || value.mKind == .Enum))
			mStrings.Release(value.mString);
	}

	public Value Get(PropertyDescriptor property)
	{
		return mValues[property.mIndex];
	}

	// Public write path: only Value properties, type-checked.
	public Result<bool, PropertyError> Set(PropertyDescriptor property, Value value)
	{
		if (!property.mIsWritable)
			return .Err(.ReadOnly);
		if (!KindFits(property, value))
			return .Err(.TypeMismatch);

		// A property that styles (or animation, ...) contribute to: the written value becomes the authored contribution, which
		// ranks above styles and below animation, so the arbitration order holds for every writer.
		let stack = mStacks[property.mIndex];
		if (stack != null)
		{
			stack.RemoveLayerSource(.InstanceOverride, cAuthoredSource);
			AddContribution(stack, .InstanceOverride, cAuthoredSource, value, .Replace, 1, 0);
			return Recompute(property);
		}
		mExplicit[property.mIndex] = true;
		return SetInternal(property, value);
	}

	static bool KindFits(PropertyDescriptor property, Value value)
	{
		return value.mKind == property.mValueKind || (value.mKind == .Int && property.mValueKind == .Float);
	}

	void AddContribution(ContributionStack stack, PropertyLayer layer, int source, Value value, ContributionBlend blend, float weight, int order)
	{
		Contribution contribution = default;
		contribution.mLayer = layer;
		contribution.mSource = source;
		contribution.mValue = value;
		contribution.mBlend = blend;
		contribution.mWeight = weight;
		contribution.mOrder = order;
		stack.Add(contribution);
	}

	// Value after applying every layer in order (Default < Theme < ComponentStyle < StateStyle < InstanceOverride < Animation < Blueprint < Solver).
	Result<bool, PropertyError> Recompute(PropertyDescriptor property)
	{
		let stack = mStacks[property.mIndex];
		let resolved = (stack != null) ? stack.Resolve(mDefaults[property.mIndex]) : mDefaults[property.mIndex];
		return SetInternal(property, resolved);
	}

	// Adds (or replaces, same layer + source + order) a contribution of a system. The authored value, if any, keeps contributing
	// from the InstanceOverride layer.
	public Result<bool, PropertyError> SetContribution(PropertyDescriptor property, PropertyLayer layer, int source, Value value,
		ContributionBlend blend = .Replace, float weight = 1, int order = 0)
	{
		if (!KindFits(property, value))
			return .Err(.TypeMismatch);
		var stack = mStacks[property.mIndex];
		if (stack == null)
		{
			stack = new ContributionStack();
			mStacks[property.mIndex] = stack;
			if (mExplicit[property.mIndex])
				AddContribution(stack, .InstanceOverride, cAuthoredSource, mValues[property.mIndex], .Replace, 1, 0);
		}
		stack.RemoveLayerSource(layer, source, order);
		AddContribution(stack, layer, source, value, blend, weight, order);
		return Recompute(property);
	}

	public Result<bool, PropertyError> ClearContribution(PropertyDescriptor property, PropertyLayer layer, int source)
	{
		let stack = mStacks[property.mIndex];
		if (stack == null || !stack.RemoveLayerSource(layer, source))
			return .Ok(false);
		return Recompute(property);
	}

	// Removes everything one writer contributed to this object (a style system restyling, a controller being disabled).
	public void ClearSource(int source)
	{
		for (int i < mStacks.Count)
		{
			let stack = mStacks[i];
			if (stack == null || !stack.RemoveSource(source))
				continue;
			let properties = scope List<PropertyDescriptor>();
			mType.CollectProperties(properties);
			for (let property in properties)
			{
				if (property.mIndex == i)
					Recompute(property);
			}
		}
	}

	public bool HasContributions(PropertyDescriptor property) => mStacks[property.mIndex] != null && mStacks[property.mIndex].mCount > 0;

	// Write path for the owning object (State properties). Returns true if the value changed.
	public Result<bool, PropertyError> SetInternal(PropertyDescriptor property, Value value)
	{
		if (value.mKind != property.mValueKind && !(value.mKind == .Int && property.mValueKind == .Float))
			return .Err(.TypeMismatch);

		var stored = value;
		if (property.mValueKind == .Float && value.mKind == .Int)
			stored = Value.FromFloat((double)value.mInt);

		let old = mValues[property.mIndex];
		if (old.Equals(stored))
			return .Ok(false);

		RetainValue(stored);
		mValues[property.mIndex] = stored;
		ReleaseValue(old);
		if (mObservables[property.mIndex] != null)
			mObservables[property.mIndex].NotifyChanged();
		if (mListener != null)
			mListener.OnPropertyChanged(this, property, old, stored);
		return .Ok(true);
	}

	public ObservableValue Observe(PropertyDescriptor property)
	{
		if (mObservables[property.mIndex] == null)
			mObservables[property.mIndex] = new ObservableValue();
		return mObservables[property.mIndex];
	}
}
