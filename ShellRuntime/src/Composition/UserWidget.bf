namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Elements;
using Shell.Widgets;
using Shell.Composition;

// A live instance of a UserWidget definition. One widget class for all definitions: the public surface of an instance is the
// definition's exposed interface, described by a per-definition TypeDescriptor (see UserWidgetTypeFactory).
//
// Structure: the instance is a normal widget (it has bounds, a parent, bindings, events of its own). Below it hangs exactly one hidden
// content root: the widget tree built from the definition. Everything inside has ids derived from the instance id
// (StableId.Combine(instance id, node id)), so any number of instances of one definition are independent and overrides can address
// inner objects by a path of authored ids.
//
// Members: the content is created and destroyed by the UserWidgetHost; an instance of a missing definition (or one that would create a
// cycle) is a placeholder with IsMissing = true and no content.
class UserWidget : Widget
{
	static public TypeDescriptor sBaseType;
	static public PropertyDescriptor sFillContent;          // content root follows the instance size (default true)
	static public PropertyDescriptor sIsMissing;            // definition missing / cyclic / too deep
	static public PropertyDescriptor sDefinitionRevision;   // revision of the definition this instance was built from

	public TypeDescriptor mType;                // per-definition type; null for placeholders
	public UserWidgetHost mHost;
	public StableId mDefinitionId;
	public WidgetNodeData mNode;                // saved instance description (property values, overrides); not owned
	public Widget mContent;
	public int mDepth;
	public uint32 mBuiltRevision;
	public bool bMissing;
	public List<ExposedLink> mLinks = new .() ~ DeleteContainerAndItems!(_);
	bool bMirroring;

	static public bool Register(RuntimeContext context)
	{
		if (sBaseType == null)
		{
			let b = new WidgetTypeBuilder("UserWidget", WidgetTypes.sWidget);
			sFillContent = b.AddValue("FillContent", .Bool, Value.FromBool(true), .Layout);
			sIsMissing = b.AddState("IsMissing", .Bool, Value.FromBool(false));
			sDefinitionRevision = b.AddState("DefinitionRevision", .Int, Value.FromInt(0), .None);
			sBaseType = b.mType;
			delete b;
		}
		return context.mTypes.Register(sBaseType, context.mDiagnostics, false);
	}

	public override TypeDescriptor GetDescriptor() => (mType != null) ? mType : sBaseType;

	// ---- Linking of the exposed interface ----

	ExposedLink FindLink(PropertyDescriptor property)
	{
		for (let link in mLinks)
		{
			if (link.mOuterProperty == property)
				return link;
		}
		return null;
	}

	// Connects every exposed member to its inner target (the content must exist). Members whose target is missing are reported.
	public void Link(CompositionDefinition definition)
	{
		Unlink();
		if (definition == null || mContent == null)
			return;

		for (let member in definition.mExposed)
		{
			let link = new ExposedLink();
			link.mOwner = this;
			link.mMember = member;
			mLinks.Add(link);

			let target = mContext.FindByStableId(StableId.Combine(mStableId, member.mInnerTarget));
			if (target == null)
			{
				mContext.mDiagnostics.Warning("UWD0020", scope $"The exposed member '{member.mPublicName}' points to an object that does not exist in the definition.", mStableId);
				continue;
			}
			link.mTarget = target.mHandle;

			switch (member.mKind)
			{
			case .Property:
				link.mOuterProperty = GetDescriptor().FindProperty(member.mPublicName);
				link.mInnerProperty = target.GetDescriptor().FindProperty(member.mInnerMember);
				if (link.mOuterProperty == null || link.mInnerProperty == null)
				{
					mContext.mDiagnostics.Warning("UWD0021", scope $"The exposed property '{member.mPublicName}' cannot be linked to '{member.mInnerMember}'.", mStableId);
					link.mTarget = Handle.sNone;
					continue;
				}
				link.mObserved = target.GetObservable(link.mInnerProperty);
				if (link.mObserved != null)
					link.mObserved.AddObserver(link);
				Mirror(link);

			case .Event:
			{
				let widget = target as Widget;
				link.mOuterEvent = GetDescriptor().FindEvent(member.mPublicName);
				link.mInnerEvent = (widget != null) ? widget.GetDescriptor().FindEvent(member.mInnerMember) : null;
				if (link.mOuterEvent == null || link.mInnerEvent == null)
				{
					mContext.mDiagnostics.Warning("UWD0022", scope $"The exposed event '{member.mPublicName}' cannot be linked to '{member.mInnerMember}'.", mStableId);
					link.mTarget = Handle.sNone;
					continue;
				}
				link.mSubscription = widget.Subscribe(link.mInnerEvent, link);
				link.bSubscribed = true;
			}

			case .Method:
			{
				let widget = target as Widget;
				link.mOuterMethod = GetDescriptor().FindMethod(member.mPublicName);
				link.mInnerMethod = (widget != null) ? widget.GetDescriptor().FindMethod(member.mInnerMember) : null;
				if (link.mOuterMethod == null || link.mInnerMethod == null)
				{
					mContext.mDiagnostics.Warning("UWD0023", scope $"The exposed method '{member.mPublicName}' cannot be linked to '{member.mInnerMember}'.", mStableId);
					link.mTarget = Handle.sNone;
				}
			}

			case .Variable:
				// Blueprint variables are exposed through the Blueprint host (a later stage).
				mContext.mDiagnostics.Warning("UWD0024", scope $"The exposed variable '{member.mPublicName}' needs the Blueprint host and is not available yet.", mStableId);
				link.mTarget = Handle.sNone;
			}
		}
	}

	public void Unlink()
	{
		for (let link in mLinks)
		{
			let target = mContext.FindByStableId(StableId.Combine(mStableId, link.mMember.mInnerTarget));
			if (link.mObserved != null && target != null && target.mHandle == link.mTarget)
				link.mObserved.RemoveObserver(link);
			if (link.bSubscribed && target != null && target.mHandle == link.mTarget)
			{
				let widget = target as Widget;
				if (widget != null)
					widget.Unsubscribe(link.mSubscription);
			}
		}
		mLinks.ClearAndDeleteItems();
	}

	// An inner object is being destroyed: forget links that point to it.
	public void OnTargetDestroying(Handle target)
	{
		for (let link in mLinks)
		{
			if (link.mTarget == target)
				link.Drop();
		}
	}

	// inner -> instance
	public void Mirror(ExposedLink link)
	{
		let target = mContext.Resolve<RuntimeObject>(link.mTarget);
		if (target == null || link.mOuterProperty == null)
			return;
		bMirroring = true;
		mProperties.SetInternal(link.mOuterProperty, target.GetProperty(link.mInnerProperty));
		bMirroring = false;
	}

	// instance -> inner (a writable exposed property was set on the instance)
	public override void OnPropertyChanged(PropertyStore store, PropertyDescriptor property, Value oldValue, Value newValue)
	{
		base.OnPropertyChanged(store, property, oldValue, newValue);
		if (bMirroring)
			return;

		if (property == WidgetTypes.sBounds || property == sFillContent)
			FitContent();

		let link = FindLink(property);
		if (link == null || link.mInnerProperty == null)
			return;
		let target = mContext.Resolve<RuntimeObject>(link.mTarget);
		if (target != null && target.SetProperty(link.mInnerProperty, newValue) case .Err(let error))
			mContext.mDiagnostics.Warning("UWD0025", scope $"Writing the exposed property '{link.mMember.mPublicName}' failed: {error}.", mStableId);
	}

	// The content root follows the instance size unless FillContent is off.
	public void FitContent()
	{
		if (mContent == null || !mProperties.Get(sFillContent).AsBool(true))
			return;
		let bounds = mBounds;
		mContent.SetBounds(RectF(0, 0, bounds.mWidth, bounds.mHeight));
	}

	protected override Result<Value, CallError> OnInvokeMethod(MethodDescriptor method, List<Value> arguments)
	{
		for (let link in mLinks)
		{
			if (link.mOuterMethod != method)
				continue;
			let widget = mContext.Resolve<Widget>(link.mTarget);
			if (widget == null || link.mInnerMethod == null)
				return .Err(.UnknownMethod);
			return widget.Invoke(link.mInnerMethod, arguments);
		}
		return base.OnInvokeMethod(method, arguments);
	}

	// The exposed interface changed: the property store gets the new type. Values of properties that still exist (same name and kind)
	// are carried over. The caller detaches bindings that read from this widget first (BindingSystem.TakeSourcesOf).
	public void SwapType(TypeDescriptor newType)
	{
		let old = mProperties;
		let oldType = GetDescriptor();
		mType = newType;
		let fresh = new PropertyStore(newType, mContext.mStrings);
		let properties = scope List<PropertyDescriptor>();
		oldType.CollectProperties(properties);
		for (let property in properties)
		{
			let other = newType.FindProperty(property.mName);
			if (other != null && other.mValueKind == property.mValueKind)
				fresh.SetInternal(other, old.Get(property));
		}
		fresh.mListener = this;
		mProperties = fresh;
		delete old;
	}

	protected override void OnDestroy()
	{
		mLinks.ClearAndDeleteItems();      // the inner objects are already gone (destroyed before their owner); nothing to unsubscribe
		base.OnDestroy();
	}
}
