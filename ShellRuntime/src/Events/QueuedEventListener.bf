namespace Shell.Runtime;

using System;
using Shell.Core;
using Shell.Reflection;

// Subscribes to widget events and forwards them to an EventQueue. This is the adapter between the immediate widget event model
// and the queued, run-to-completion model of Blueprints: a widget raises the event synchronously, the Blueprint host handles it
// in its own phase.
class QueuedEventListener : IEventListener
{
	EventQueue mQueue;

	public this(EventQueue queue)
	{
		mQueue = queue;
	}

	public void OnEvent(RuntimeObject source, EventDescriptor ev, Span<Value> arguments)
	{
		let queued = new QueuedEvent(source.mContext.mStrings);
		queued.mSource = source.mHandle;
		queued.mEvent = ev;
		for (let argument in arguments)
			queued.AddArgument(argument);
		mQueue.Enqueue(queued);
	}
}
