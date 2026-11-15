namespace Shell.Reflection;

using System;
using System.Collections;
using Shell.Core;

// Runtime type description: properties, events and methods, with single inheritance. Names are unique per type
// (including inherited members). Indices continue after the base type's, so a PropertyStore for a derived type is
// a superset of the base type's layout.
class TypeDescriptor
{
	public StringView mName;
	public TypeCategory mCategory;
	public TypeDescriptor mBase;
	public List<PropertyDescriptor> mProperties = new .() ~ DeleteContainerAndItems!(_);
	public List<EventDescriptor> mEvents = new .() ~ DeleteContainerAndItems!(_);
	public List<MethodDescriptor> mMethods = new .() ~ DeleteContainerAndItems!(_);
	public bool bFinished;
	List<(PropertyDescriptor property, Value value)> mDefaultOverrides = new .() ~ delete _;

	int mPropertyBase;
	int mEventBase;
	int mMethodBase;

	public this(StringView name, TypeCategory category, TypeDescriptor baseType = null)
	{
		mName = name;
		mCategory = category;
		mBase = baseType;
	}

	public int mTotalPropertyCount => mPropertyBase + mProperties.Count;
	public int mTotalEventCount => mEventBase + mEvents.Count;
	public int mTotalMethodCount => mMethodBase + mMethods.Count;

	public PropertyDescriptor AddProperty(PropertyDescriptor property)
	{
		Runtime.Assert(!bFinished, "Type is finished");
		mProperties.Add(property);
		return property;
	}

	public EventDescriptor AddEvent(EventDescriptor ev)
	{
		Runtime.Assert(!bFinished, "Type is finished");
		mEvents.Add(ev);
		return ev;
	}

	public MethodDescriptor AddMethod(MethodDescriptor method)
	{
		Runtime.Assert(!bFinished, "Type is finished");
		mMethods.Add(method);
		return method;
	}

	// A derived type can change the default of an inherited property (a Button is focusable by default) without declaring a
	// new property.
	public void OverrideDefault(PropertyDescriptor property, Value value)
	{
		mDefaultOverrides.Add((property, value));
	}

	// Applies the overrides of this type and its base types, base first (later types win).
	public void ApplyDefaultOverrides(Value[] values)
	{
		if (mBase != null)
			mBase.ApplyDefaultOverrides(values);
		for (let entry in mDefaultOverrides)
			values[entry.property.mIndex] = entry.value;
	}

	// Assigns member indices. The base type must be finished first. Returns false (and reports) on duplicate names.
	public bool Finish(DiagnosticSink sink)
	{
		if (bFinished)
			return true;
		if (mBase != null && !mBase.bFinished)
		{
			sink.Error("REF0001", scope $"Type '{mName}': base type '{mBase.mName}' must be registered first.");
			return false;
		}

		mPropertyBase = (mBase != null) ? mBase.mTotalPropertyCount : 0;
		mEventBase = (mBase != null) ? mBase.mTotalEventCount : 0;
		mMethodBase = (mBase != null) ? mBase.mTotalMethodCount : 0;

		bool bOk = true;
		for (int i < mProperties.Count)
		{
			let property = mProperties[i];
			property.mIndex = mPropertyBase + i;
			if (FindProperty(property.mName) != property)
			{
				sink.Error("REF0002", scope $"Type '{mName}': duplicate property '{property.mName}'.");
				bOk = false;
			}
		}
		for (int i < mEvents.Count)
			mEvents[i].mIndex = mEventBase + i;
		for (int i < mMethods.Count)
			mMethods[i].mIndex = mMethodBase + i;

		bFinished = bOk;
		return bOk;
	}

	// Searches this type, then its base types.
	public PropertyDescriptor FindProperty(StringView name)
	{
		var type = this;
		while (type != null)
		{
			for (let property in type.mProperties)
			{
				if (property.mName == name)
					return property;
			}
			type = type.mBase;
		}
		return null;
	}

	public EventDescriptor FindEvent(StringView name)
	{
		var type = this;
		while (type != null)
		{
			for (let ev in type.mEvents)
			{
				if (ev.mName == name)
					return ev;
			}
			type = type.mBase;
		}
		return null;
	}

	public MethodDescriptor FindMethod(StringView name)
	{
		var type = this;
		while (type != null)
		{
			for (let method in type.mMethods)
			{
				if (method.mName == name)
					return method;
			}
			type = type.mBase;
		}
		return null;
	}

	public bool IsA(TypeDescriptor other)
	{
		var type = this;
		while (type != null)
		{
			if (type == other)
				return true;
			type = type.mBase;
		}
		return false;
	}

	// Properties of the whole inheritance chain, base members first (the order used for serialization).
	public void CollectProperties(List<PropertyDescriptor> output)
	{
		if (mBase != null)
			mBase.CollectProperties(output);
		for (let property in mProperties)
			output.Add(property);
	}
}
