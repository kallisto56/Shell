namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Elements;
using Shell.Widgets;
using Shell.Composition;

// Connection between one exposed member of a UserWidget instance (the public name) and the inner member it forwards to.
//   Property : the instance keeps a mirrored copy of the inner value (so bindings observe the instance, whose observables survive a
//              rebuild of the content); reading follows the inner object, writing is written through to it.
//   Event    : the inner event is re-raised on the instance.
//   Method   : the call is forwarded to the inner widget.
// Created by UserWidget.Link(), dropped by Unlink(); a link whose inner target cannot be found stays unlinked (and reported once).
class ExposedLink : IInvalidationObserver, IEventListener
{
	public UserWidget mOwner;
	public ExposedMember mMember;
	public PropertyDescriptor mOuterProperty;
	public EventDescriptor mOuterEvent;
	public MethodDescriptor mOuterMethod;
	public Handle mTarget;
	public PropertyDescriptor mInnerProperty;
	public EventDescriptor mInnerEvent;
	public MethodDescriptor mInnerMethod;
	public IObservable mObserved;
	public SubscriptionId mSubscription;
	public bool bSubscribed;

	// Inner property changed: copy it to the mirrored instance property.
	public void OnSourceChanged(IObservable source)
	{
		mOwner.Mirror(this);
	}

	// Inner event raised: raise the instance's event with the same arguments.
	public void OnEvent(RuntimeObject source, EventDescriptor ev, Span<Value> arguments)
	{
		mOwner.RaiseEvent(mOuterEvent, arguments);
	}

	// The inner object is being destroyed: forget it without touching it (its observers / dispatcher are going away).
	public void Drop()
	{
		mObserved = null;
		bSubscribed = false;
		mTarget = Handle.sNone;
	}
}
