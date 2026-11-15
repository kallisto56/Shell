namespace Shell.Reflection;

using System;

interface IEventSource
{
	SubscriptionId Subscribe(EventDescriptor ev, IEventListener listener);
	void Unsubscribe(SubscriptionId id);
}
