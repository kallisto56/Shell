namespace Shell.Simulation;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

// Starts simulated operations and completes them when the simulated clock reaches their due time.
// Completion order is (due time, creation order): deterministic.
class OperationScheduler
{
	List<SimulatedOperation> mOperations = new .() ~ DeleteContainerAndItems!(_);
	VirtualClock mClock;
	IFaultInjector mFaults;
	int mNextSequence;
	public float mDefaultLatencySeconds;       // applied to every operation unless a rule says otherwise

	public this(VirtualClock clock, IFaultInjector faults)
	{
		mClock = clock;
		mFaults = faults;
	}

	// Takes ownership. `operationName` ("files.delete") and `target` are given to the fault injector.
	public T Start<T>(T operation, StringView operationName, StringView target) where T : SimulatedOperation
	{
		operation.mSequence = mNextSequence++;
		mOperations.Add(operation);

		let decision = mFaults.Evaluate(operationName, target);
		switch (decision.mKind)
		{
		case .Fail:
			let code = decision.mErrorCode.IsEmpty ? StringView("failed") : decision.mErrorCode;
			let message = decision.mErrorMessage.IsEmpty ? StringView("The simulated operation failed.") : decision.mErrorMessage;
			operation.mDueSeconds = mClock.GetMonotonicSeconds() + decision.mDelaySeconds;
			operation.mPlannedFault = .Fail;
			operation.mPlannedErrorCode.Set(code);
			operation.mPlannedErrorMessage.Set(message);
		case .Cancel:
			operation.mDueSeconds = mClock.GetMonotonicSeconds() + decision.mDelaySeconds;
			operation.mPlannedFault = .Cancel;
		case .Delay:
			operation.mDueSeconds = mClock.GetMonotonicSeconds() + decision.mDelaySeconds;
		case .None:
			operation.mDueSeconds = mClock.GetMonotonicSeconds() + mDefaultLatencySeconds;
		}

		if (operation.mDueSeconds <= mClock.GetMonotonicSeconds())
			Complete(operation);
		return operation;
	}

	void Complete(SimulatedOperation operation)
	{
		if (operation.mStatus != .Pending)
			return;

		switch (operation.mPlannedFault)
		{
		case .Fail:
			operation.Finish(.Failed, SimulatedOperation.MakeError(operation.mPlannedErrorCode, operation.mPlannedErrorMessage));
		case .Cancel:
			operation.Finish(.Cancelled, null);
		default:
		{
			let error = operation.Execute();
			if (error != null)
				operation.Finish(.Failed, error);
			else
				operation.Finish(.Succeeded, null);
		}
		}
	}

	// Completes everything that is due, then deletes operations that finished earlier.
	public void Update()
	{
		let due = scope List<SimulatedOperation>();
		for (let operation in mOperations)
		{
			if (operation.mStatus == .Pending && operation.mDueSeconds <= mClock.GetMonotonicSeconds())
				due.Add(operation);
		}
		due.Sort(scope (a, b) => (a.mDueSeconds != b.mDueSeconds) ? (a.mDueSeconds <=> b.mDueSeconds) : (a.mSequence <=> b.mSequence));
		for (let operation in due)
			Complete(operation);

		for (var i = mOperations.Count - 1; i >= 0; i--)
		{
			let operation = mOperations[i];
			if (operation.mStatus != .Pending && (operation.bFinishedNotified || operation.mListener == null))
			{
				mOperations.RemoveAt(i);
				delete operation;
			}
		}
	}

	// Cancels everything that has not completed (environment reset).
	public void CancelAll()
	{
		for (let operation in mOperations)
			operation.Cancel();
	}

	public int mPendingCount
	{
		get
		{
			int count = 0;
			for (let operation in mOperations)
			{
				if (operation.mStatus == .Pending)
					count++;
			}
			return count;
		}
	}
}
