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
	}

	public ~this()
	{
		for (let value in mValues)
			ReleaseValue(value);
		for (let observable in mObservables)
			delete observable;
		delete mObservables;
		delete mValues;
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
		return SetInternal(property, value);
	}

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
