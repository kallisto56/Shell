namespace Shell.PlatformWin;

using System;
using System.Collections;
using Shell.Platform;

// Owns the operations a service handed out. They stay valid until Prune() (called once per frame by the platform system).
class OperationLog
{
	List<ImmediateOperation> mOperations = new .() ~ DeleteContainerAndItems!(_);

	public T Add<T>(T operation) where T : ImmediateOperation
	{
		mOperations.Add(operation);
		return operation;
	}

	public void Prune()
	{
		DeleteAndClearItems!(mOperations);
	}
}
