namespace Shell.Platform;

using System;

// Result handle of every service call that can take time, be cancelled or fail. Real services complete from native
// callbacks; the simulation completes after configured delays and can inject cancellation and failures, so UI flows
// (progress, confirmation, error dialogs) can be designed against realistic behavior.
// Lifetime: the service that returned the operation owns it. It stays valid until the service prunes finished operations
// (the next frame's Input phase for the Windows services, the next Advance() for the simulation). Callers read the result
// and attach listeners within the frame and never delete the operation.
interface IOperation
{
	OperationStatus GetStatus();
	float GetProgress();                    // 0..1, or negative if unknown
	OperationError GetError();              // valid when Failed
	void Cancel();
	void SetListener(IOperationListener listener);   // called on the update thread, in the Input phase
}
