namespace Shell.Binding;

using System;
using Shell.Core;
using Shell.Reflection;

// Runtime state of one binding. Dependency tracking: the binding observes its source; a change only marks it dirty,
// and Refresh() (Bindings phase) re-evaluates dirty bindings once per frame, in a deterministic order.
class Binding : IInvalidationObserver
{
	public BindingDescriptor mDescriptor;       // owned by the definition, not by the binding
	public RuntimeObject mOwner;
	public Value mCurrent;
	public bool bDirty = true;
	public bool bHasValue;
	public bool bIsCondition;       // drives Element.bConditionVisible instead of a property

	public Handle mSourceObject;    // object owning the observed source (none for globals / time / tokens)
	IObservable mObserved;

	public this(BindingDescriptor descriptor, RuntimeObject owner)
	{
		mDescriptor = descriptor;
		mOwner = owner;
	}

	public ~this()
	{
		Detach();
	}

	public void Attach(IBindingResolver resolver)
	{
		Detach();
		mObserved = resolver.Observe(mDescriptor.mSource, mOwner);
		let sourceObject = resolver.GetLastSourceObject();
		mSourceObject = (sourceObject != null) ? sourceObject.mHandle : Handle.sNone;
		if (mObserved != null)
			mObserved.AddObserver(this);
		bDirty = true;
	}

	public void Detach()
	{
		if (mObserved != null)
		{
			mObserved.RemoveObserver(this);
			mObserved = null;
		}
	}

	public void OnSourceChanged(IObservable source)
	{
		bDirty = true;
	}

	// Returns true if the converted value changed.
	public bool Refresh(IBindingResolver resolver)
	{
		if (!bDirty)
			return false;
		bDirty = false;
		if (mDescriptor.mMode == .OneTime && bHasValue)
			return false;

		Value value = mDescriptor.mFallback;
		if (resolver.Read(mDescriptor.mSource, mOwner) case .Ok(let raw))
			value = ConverterPipeline.Apply(mDescriptor.mConverters, raw, mOwner.mContext.mStrings);

		let changed = !bHasValue || !mCurrent.Equals(value);
		mCurrent = value;
		bHasValue = true;
		return changed;
	}
}
