namespace Shell.Reflection;

using System;
using System.Collections;
using Shell.Core;

// Subscriber list of one event source. Safe against subscribing/unsubscribing from inside a handler, and bounded
// against runaway re-entrancy (an event handler raising the same source again).
class EventDispatcher
{
	public const int cMaxDepth = 16;

	struct Entry
	{
		public SubscriptionId mId;
		public EventDescriptor mEvent;
		public IEventListener mListener;
		public bool bRemoved;
	}

	List<Entry> mEntries = new .() ~ delete _;
	uint32 mNextId = 1;
	int mDepth;

	public SubscriptionId Subscribe(EventDescriptor ev, IEventListener listener)
	{
		Entry entry = default;
		entry.mId = SubscriptionId() { mValue = mNextId++ };
		entry.mEvent = ev;
		entry.mListener = listener;
		mEntries.Add(entry);
		return entry.mId;
	}

	public void Unsubscribe(SubscriptionId id)
	{
		for (int i = 0; i < mEntries.Count; i++)
		{
			if (mEntries[i].mId.mValue != id.mValue)
				continue;
			if (mDepth > 0)
			{
				var entry = mEntries[i];
				entry.bRemoved = true;
				mEntries[i] = entry;
			}
			else
			{
				mEntries.RemoveAt(i);
			}
			return;
		}
	}

	// Listeners are called in subscription order. Returns the number of listeners that were called.
	public int Raise(RuntimeObject source, EventDescriptor ev, Span<Value> arguments)
	{
		if (mDepth >= cMaxDepth)
		{
			source.mContext.mDiagnostics.Error("EVT0001", scope $"Event '{ev.mName}' was raised re-entrantly more than {cMaxDepth} levels deep; ignored.", source.mStableId);
			return 0;
		}

		int called = 0;
		mDepth++;
		let count = mEntries.Count;     // listeners added during dispatch only see later events
		for (int i < count)
		{
			let entry = mEntries[i];
			if (entry.bRemoved || entry.mEvent != ev)
				continue;
			entry.mListener.OnEvent(source, ev, arguments);
			called++;
		}
		mDepth--;

		if (mDepth == 0)
			mEntries.RemoveAll(scope (e) => e.bRemoved);
		return called;
	}
}
