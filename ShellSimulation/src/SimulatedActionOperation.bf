namespace Shell.Simulation;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

// Records the effect of a simple shell action (open, properties, power, recycle bin) when the operation completes.
class SimulatedActionOperation : SimulatedOperation
{
	SimulatedShellIntegration mShell;
	public int mAction;         // meaning is private to SimulatedShellIntegration
	String mArgument = new .() ~ delete _;

	public this(SimulatedShellIntegration shell, int action, StringView argument)
	{
		mShell = shell;
		mAction = action;
		mArgument.Set(argument);
	}

	public override OperationError Execute()
	{
		return mShell.Perform(mAction, mArgument);
	}
}
