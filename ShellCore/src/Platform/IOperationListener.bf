namespace Shell.Platform;

using System;

interface IOperationListener
{
	void OnOperationFinished(IOperation operation);
}
