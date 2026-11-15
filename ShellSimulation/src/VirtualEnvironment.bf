namespace Shell.Simulation;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

// The simulated operating system of the editor: one complete PlatformServices set over virtual state. Time advances only
// through Advance(), so everything (delays, faults, completions) is reproducible. Nothing here can reach the host.
class VirtualEnvironment : IVirtualEnvironment
{
	public VirtualClock mClock = new .() ~ delete _;
	public FaultInjector mFaults ~ delete _;
	public VirtualFileSystem mFileSystem = new .() ~ delete _;
	public VirtualWindowManager mWindows = new .() ~ delete _;
	public VirtualMonitorService mMonitors = new .() ~ delete _;
	public OperationScheduler mScheduler ~ delete _;
	public SimulatedFileSystemService mFiles ~ delete _;
	public SimulatedApplicationLauncher mLauncher ~ delete _;
	public SimulatedShellIntegration mShell ~ delete _;
	public SimulatedClipboard mClipboard = new .() ~ delete _;
	public SimulatedNotificationService mNotifications = new .() ~ delete _;
	public SimulatedTextInputService mTextInput = new .() ~ delete _;
	public PlatformServices mServices = new .() ~ delete _;

	Dictionary<String, EnvironmentSnapshot> mSnapshots = new .() ~ DeleteDictionaryAndKeysAndValues!(_);
	const String cInitial = "initial";

	public this(uint64 faultSeed = 1)
	{
		mFaults = new FaultInjector(faultSeed);
		mScheduler = new OperationScheduler(mClock, mFaults);
		mFiles = new SimulatedFileSystemService(mFileSystem, mScheduler);
		mLauncher = new SimulatedApplicationLauncher(mWindows, mScheduler);
		mShell = new SimulatedShellIntegration(mFileSystem, mScheduler, mLauncher);

		mServices.mClock = mClock;
		mServices.mWindows = mWindows;
		mServices.mMonitors = mMonitors;
		mServices.mFiles = mFiles;
		mServices.mLauncher = mLauncher;
		mServices.mShell = mShell;
		mServices.mNotifications = mNotifications;
		mServices.mClipboard = mClipboard;
		mServices.mTextInput = mTextInput;
		mFileSystem.mNowUtcTicks = mClock.GetUtcTicks();
	}

	// A typical single-monitor desktop with a home folder, sample files and a few applications.
	static public VirtualEnvironment CreateDefault(uint64 faultSeed = 1)
	{
		let env = new VirtualEnvironment(faultSeed);
		env.mMonitors.AddMonitor("Virtual Display 1", RectF(0, 0, 1920, 1080), 1.0f, true);

		let fs = env.mFileSystem;
		fs.EnsureFolder("C:/Windows");
		fs.EnsureFolder("C:/Users/Me/Desktop");
		fs.EnsureFolder("C:/Users/Me/Downloads");
		fs.EnsureFolder("C:/Users/Me/Pictures");
		fs.AddFile("C:/Users/Me/Documents/Report.docx", 48213);
		fs.AddFile("C:/Users/Me/Documents/Budget.xlsx", 120344);
		fs.AddFile("C:/Users/Me/Documents/Notes.txt", 1204);
		fs.AddFile("C:/Users/Me/Documents/Locked.txt", 88, false, true);
		fs.AddFile("C:/Users/Me/Pictures/Holiday.png", 2480112);
		fs.AddFile("C:/Users/Me/Downloads/setup.exe", 15728640);

		let shell = env.mShell;
		shell.SetFolder(.Home, "C:/Users/Me");
		shell.SetFolder(.Desktop, "C:/Users/Me/Desktop");
		shell.SetFolder(.Documents, "C:/Users/Me/Documents");
		shell.SetFolder(.Downloads, "C:/Users/Me/Downloads");
		shell.SetFolder(.Pictures, "C:/Users/Me/Pictures");
		shell.SetFolder(.Drives, "");

		env.mLauncher.AddApplication("notepad", "Notepad", "C:/Windows/notepad.exe");
		env.mLauncher.AddApplication("explorer", "File Explorer", "C:/Windows/explorer.exe");
		env.mLauncher.AddApplication("paint", "Paint", "C:/Windows/mspaint.exe");

		env.TakeInitialSnapshot();
		return env;
	}

	void TakeInitialSnapshot()
	{
		Capture(cInitial);
	}

	void Capture(StringView id)
	{
		let snapshot = new EnvironmentSnapshot();
		snapshot.mFileSystem = mFileSystem.Clone();
		snapshot.mWindows = new VirtualWindowManager();
		snapshot.mWindows.CopyFrom(mWindows);
		snapshot.mClockSeconds = mClock.GetMonotonicSeconds();

		let probe = scope String(id);
		if (mSnapshots.TryGet(probe, var oldKey, var oldSnapshot))
		{
			mSnapshots.Remove(probe);
			delete oldKey;
			delete oldSnapshot;
		}
		mSnapshots[new String(id)] = snapshot;
	}

	// ---- IVirtualEnvironment ----

	public PlatformServices GetServices() => mServices;
	public IFaultInjector GetFaultInjector() => mFaults;

	public void Reset()
	{
		mScheduler.CancelAll();
		mScheduler.Update();
		RestoreSnapshot(cInitial);
		mClipboard.SetText("");
	}

	public void Advance(double seconds)
	{
		mClock.Advance(seconds);
		mFileSystem.mNowUtcTicks = mClock.GetUtcTicks();
		mScheduler.Update();
	}

	public bool SaveSnapshot(String outSnapshotId)
	{
		outSnapshotId.AppendF("snapshot-{}", mSnapshots.Count);
		Capture(outSnapshotId);
		return true;
	}

	public bool RestoreSnapshot(StringView snapshotId)
	{
		let key = scope String(snapshotId);
		if (!mSnapshots.TryGetValue(key, let snapshot))
			return false;

		mScheduler.CancelAll();
		mFileSystem.CopyFrom(snapshot.mFileSystem);
		mWindows.CopyFrom(snapshot.mWindows);
		mClock.Set(snapshot.mClockSeconds);
		return true;
	}
}
