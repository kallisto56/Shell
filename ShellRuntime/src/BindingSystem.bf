namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Binding;
using Shell.Elements;
using Shell.Reflection;
using Shell.Widgets;

// Bindings phase: re-evaluates dirty bindings once per frame, in registration order, and writes the results into the bound
// properties (or into Element.bConditionVisible for visibility conditions).
//
// Lifetime: the system keeps bindings that are owned by widgets / elements. When an owner is destroyed its bindings are removed
// first; when a binding's *source* object is destroyed the binding is detached (so it never touches a freed observable) and
// re-evaluated, which reports the missing source and applies the binding's fallback value.
class BindingSystem : IRuntimeSystem, IObjectDestroyListener
{
	RuntimeContext mContext;
	List<Binding> mBindings = new .() ~ delete _;     // not owned
	IBindingResolver mResolver;
	public int mOrder;

	public this(RuntimeContext context, IBindingResolver resolver)
	{
		mContext = context;
		mResolver = resolver;
		context.AddDestroyListener(this);
	}

	public ~this()
	{
		mContext.RemoveDestroyListener(this);
	}

	public UpdatePhase GetPhase() => .Bindings;
	public int GetOrder() => mOrder;

	// ---- Registration (the binding is owned by `owner`) ----

	public Binding AddElementBinding(Element element, BindingDescriptor descriptor)
	{
		let binding = new Binding(descriptor, element);
		element.mBindings.Add(binding);
		Track(binding);
		return binding;
	}

	public Binding AddWidgetBinding(Widget widget, BindingDescriptor descriptor)
	{
		let binding = new Binding(descriptor, widget);
		widget.mBindings.Add(binding);
		Track(binding);
		return binding;
	}

	// Visibility condition of an element ("show only when ..."). Replaces an existing condition.
	public Binding SetCondition(Element element, BindingDescriptor descriptor)
	{
		if (element.mVisibleBinding != null)
		{
			Untrack(element.mVisibleBinding);
			delete element.mVisibleBinding;
		}
		let binding = new Binding(descriptor, element);
		binding.bIsCondition = true;
		element.mVisibleBinding = binding;
		Track(binding);
		return binding;
	}

	void Track(Binding binding)
	{
		mBindings.Add(binding);
		binding.Attach(mResolver);
	}

	void Untrack(Binding binding)
	{
		mBindings.Remove(binding);
		binding.Detach();
	}

	public void OnObjectDestroying(RuntimeObject object)
	{
		for (var i = mBindings.Count - 1; i >= 0; i--)
		{
			let binding = mBindings[i];
			if (binding.mOwner == object)
			{
				binding.Detach();
				mBindings.RemoveAt(i);
			}
			else if (binding.mSourceObject == object.mHandle)
			{
				binding.Detach();
				binding.mSourceObject = Handle.sNone;
				binding.bDirty = true;
			}
		}
	}

	public void Update(FrameContext frame)
	{
		for (let binding in mBindings)
		{
			if (!binding.Refresh(mResolver))
				continue;

			let owner = binding.mOwner;
			if (!owner.mIsAlive)
				continue;

			if (binding.bIsCondition)
			{
				let element = owner as Element;
				element.bConditionVisible = binding.mCurrent.AsBool(true);
				let widget = element.mTree.mOwner as Widget;
				if (widget != null)
					widget.Invalidate(.Layout | .Visual);
				continue;
			}

			let host = owner as IPropertyHost;
			if (host == null)
				continue;
			let property = host.GetDescriptor().FindProperty(binding.mDescriptor.mTargetProperty);
			if (property == null)
			{
				owner.mContext.mDiagnostics.Error("BND0010", scope $"Bound property '{binding.mDescriptor.mTargetProperty}' does not exist on '{host.GetDescriptor().mName}'.", owner.mStableId);
				continue;
			}
			if (host.SetProperty(property, binding.mCurrent) case .Err(let error))
				owner.mContext.mDiagnostics.Error("BND0011", scope $"Binding could not write '{property.mName}': {error}.", owner.mStableId);
		}
	}
}
