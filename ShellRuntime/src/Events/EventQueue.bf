namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;

// FIFO of widget events waiting for the Blueprint host. Bounded: when it overflows the newest events are dropped and a
// diagnostic is reported (a runaway event loop must not eat the process).
class EventQueue
{
	public const int cMaxQueued = 4096;

	List<QueuedEvent> mEvents = new .() ~ DeleteContainerAndItems!(_);
	RuntimeContext mContext;
	bool bOverflowReported;

	public this(RuntimeContext context)
	{
		mContext = context;
	}

	public int mCount => mEvents.Count;

	public void Enqueue(QueuedEvent queued)
	{
		if (mEvents.Count >= cMaxQueued)
		{
			if (!bOverflowReported)
			{
				mContext.mDiagnostics.Error("EVT0002", scope $"The widget event queue is full ({cMaxQueued}); further events are dropped.");
				bOverflowReported = true;
			}
			delete queued;
			return;
		}
		mEvents.Add(queued);
	}

	// Moves everything queued so far to `output` (caller owns and deletes the events). Events raised while the caller processes
	// them are queued for the next call (run-to-completion, no interleaving).
	public void Take(List<QueuedEvent> output)
	{
		output.AddRange(mEvents);
		mEvents.Clear();
		bOverflowReported = false;
	}
}
