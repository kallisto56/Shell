namespace Shell.Core;

using System;
using System.Collections;

// Structural changes (adding/removing/reparenting objects) requested while a tree is being traversed are queued here
// and applied during the Commit phase. This is the only mechanism that may change a tree while it is traversed.
class MutationQueue
{
	public const int cMaxRounds = 64;

	List<Mutation> mPending = new .() ~ DeleteContainerAndItems!(_);

	public int mPendingCount => mPending.Count;

	public void Defer(Mutation mutation)
	{
		mPending.Add(mutation);
	}

	// Runs queued mutations in FIFO order. Mutations may queue more; the cascade is bounded.
	public int Flush(RuntimeContext context)
	{
		int executed = 0;
		int rounds = 0;
		while (mPending.Count > 0)
		{
			rounds++;
			if (rounds > cMaxRounds)
			{
				context.mDiagnostics.Error("CORE0001", "Deferred mutations kept queuing more mutations; the cascade was cut off.");
				DeleteAndClearItems!(mPending);
				break;
			}

			let batch = scope List<Mutation>();
			batch.AddRange(mPending);
			mPending.Clear();
			for (let mutation in batch)
			{
				mutation.Apply(context);
				delete mutation;
				executed++;
			}
		}
		return executed;
	}
}
