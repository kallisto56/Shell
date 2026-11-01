namespace Shell.Simulation;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

// An operation of a simulated service. The *effect* (changing the virtual file system, creating a window ...) happens in
// Execute(), when the operation completes; cancelling an operation that has not completed therefore changes nothing, like
// cancelling a real pending operation.
//
// Lifetime: created by a service, owned by the OperationScheduler, deleted when the scheduler prunes finished operations
// (after the frame in which they finished). Callers must not keep the pointer longer.
abstract class SimulatedOperation : IOperation
{
	public OperationStatus mStatus = .Pending;
	public float mProgress;
	public OperationError mError ~ delete _;
	public IOperationListener mListener;
	public double mDueSeconds;                  // simulated time at which the operation completes
	public int mSequence;
	public bool bFinishedNotified;

	// Planned by the scheduler from the fault injector's decision.
	public FaultKind mPlannedFault;
	public String mPlannedErrorCode = new .() ~ delete _;
	public String mPlannedErrorMessage = new .() ~ delete _;

	// Performs the effect. Return null on success or an error to fail the operation.
	public abstract OperationError Execute();

	public OperationStatus GetStatus() => mStatus;
	public float GetProgress() => (mStatus == .Pending) ? mProgress : 1.0f;
	public OperationError GetError() => mError;

	public void Cancel()
	{
		if (mStatus == .Pending)
			Finish(.Cancelled, null);
	}

	public void SetListener(IOperationListener listener)
	{
		mListener = listener;
		if (mStatus != .Pending)
			Notify();       // already finished: report right away
	}

	public void Finish(OperationStatus status, OperationError error)
	{
		if (mStatus != .Pending)
		{
			delete error;
			return;
		}
		mStatus = status;
		delete mError;
		mError = error;
		Notify();
	}

	void Notify()
	{
		if (mListener != null && !bFinishedNotified)
		{
			bFinishedNotified = true;
			mListener.OnOperationFinished(this);
		}
	}

	static public OperationError MakeError(StringView code, StringView message)
	{
		let error = new OperationError();
		error.mCode.Set(code);
		error.mMessage.Set(message);
		return error;
	}
}
