namespace Shell.Simulation;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

// Launching creates a virtual window (the "application") when the operation completes.
class SimulatedLaunchOperation : SimulatedOperation
{
	VirtualWindowManager mWindows;
	SimulatedApplicationLauncher mLauncher;
	String mTarget = new .() ~ delete _;
	String mTitle = new .() ~ delete _;

	public this(VirtualWindowManager windows, SimulatedApplicationLauncher launcher, StringView target, StringView title)
	{
		mWindows = windows;
		mLauncher = launcher;
		mTarget.Set(target);
		mTitle.Set(title);
	}

	public override OperationError Execute()
	{
		let bounds = mLauncher.NextWindowBounds();
		mWindows.CreateWindow(mTitle, mTarget, bounds);
		return null;
	}
}
