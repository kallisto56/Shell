namespace Shell.PlatformWin;

using System;
using System.Collections;
using Shell.Platform;

// Operation of a real service that already finished when it is returned (the Windows services in this stage run on the
// update thread and complete synchronously). Listeners are called when attached. Owned by the service (OperationLog).
class ImmediateOperation : IOperation
{
	public OperationStatus mStatus = .Succeeded;
	public OperationError mError ~ delete _;
	IOperationListener mListener;

	public OperationStatus GetStatus() => mStatus;
	public float GetProgress() => 1.0f;
	public OperationError GetError() => mError;
	public void Cancel() { }        // nothing left to cancel

	public void SetListener(IOperationListener listener)
	{
		mListener = listener;
		if (listener != null)
			listener.OnOperationFinished(this);
	}

	public void Fail(OperationError error)
	{
		mStatus = .Failed;
		delete mError;
		mError = error;
	}
}
