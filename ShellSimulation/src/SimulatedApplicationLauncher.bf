namespace Shell.Simulation;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

class SimulatedApplicationLauncher : IApplicationLauncher
{
	List<ApplicationEntry> mCatalog = new .() ~ DeleteContainerAndItems!(_);
	public VirtualWindowManager mWindows;
	OperationScheduler mScheduler;
	int mLaunchCount;

	public this(VirtualWindowManager windows, OperationScheduler scheduler)
	{
		mWindows = windows;
		mScheduler = scheduler;
	}

	public void AddApplication(StringView id, StringView displayName, StringView target)
	{
		let entry = new ApplicationEntry();
		entry.mId.Set(id);
		entry.mDisplayName.Set(displayName);
		entry.mTarget.Set(target);
		mCatalog.Add(entry);
	}

	// Cascading placement so launched windows do not stack exactly on top of each other.
	public RectF NextWindowBounds()
	{
		let offset = (float)((mLaunchCount++ % 8) * 32);
		return RectF(80 + offset, 60 + offset, 900, 600);
	}

	public IOperation Launch(LaunchRequest request)
	{
		var title = StringView(request.mTarget);
		for (let entry in mCatalog)
		{
			if (entry.mId == request.mTarget || entry.mTarget == request.mTarget)
			{
				title = entry.mDisplayName;
				break;
			}
		}
		return mScheduler.Start(new SimulatedLaunchOperation(mWindows, this, request.mTarget, title), "launcher.launch", request.mTarget);
	}

	public void GetInstalledApplications(List<ApplicationEntry> output)
	{
		output.AddRange(mCatalog);
	}
}
