namespace Shell.Simulation;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

// Special folders map to paths of the virtual file system. Power actions are recorded (mLastPowerAction) instead of
// being executed, so a shutdown confirmation flow can be designed and tested safely.
class SimulatedShellIntegration : IShellIntegration
{
	const int cOpen = 0;
	const int cProperties = 1;
	const int cEmptyBin = 2;
	const int cPower = 3;

	public VirtualFileSystem mFileSystem;
	OperationScheduler mScheduler;
	SimulatedApplicationLauncher mLauncher;
	Dictionary<SpecialFolder, String> mFolders = new .() ~ DeleteDictionaryAndValues!(_);

	public PowerAction mLastPowerAction;
	public String mLastPropertiesPath = new .() ~ delete _;
	public String mLastOpenedPath = new .() ~ delete _;
	public int mPowerActionCount;

	public this(VirtualFileSystem fileSystem, OperationScheduler scheduler, SimulatedApplicationLauncher launcher)
	{
		mFileSystem = fileSystem;
		mScheduler = scheduler;
		mLauncher = launcher;
	}

	public void SetFolder(SpecialFolder folder, StringView path)
	{
		if (mFolders.TryGetValue(folder, let existing))
			existing.Set(path);
		else
			mFolders[folder] = new String(path);
	}

	public String GetSpecialFolderPath(SpecialFolder folder)
	{
		if (folder == .RecycleBin)
			return new String("$Recycle.Bin");
		if (mFolders.TryGetValue(folder, let path))
			return new String(path);
		return null;
	}

	public OperationError Perform(int action, StringView argument)
	{
		switch (action)
		{
		case cOpen:
		{
			let node = mFileSystem.Find(argument);
			if (node == null)
				return SimulatedOperation.MakeError("not-found", scope $"'{argument}' does not exist.");
			mLastOpenedPath.Set(argument);
			if (!node.mIsFolder)
				mLauncher.mWindows.CreateWindow(node.mName, argument, mLauncher.NextWindowBounds());
		}
		case cProperties:
		{
			if (mFileSystem.Find(argument) == null)
				return SimulatedOperation.MakeError("not-found", scope $"'{argument}' does not exist.");
			mLastPropertiesPath.Set(argument);
		}
		case cEmptyBin:
			mFileSystem.EmptyRecycleBin();
		case cPower:
		{
			mPowerActionCount++;
			if (argument == "shutdown") mLastPowerAction = .Shutdown;
			else if (argument == "restart") mLastPowerAction = .Restart;
			else if (argument == "lock") mLastPowerAction = .Lock;
			else mLastPowerAction = .SignOut;
		}
		}
		return null;
	}

	public IOperation OpenPath(StringView path) => mScheduler.Start(new SimulatedActionOperation(this, cOpen, path), "shell.open", path);
	public IOperation ShowProperties(StringView path) => mScheduler.Start(new SimulatedActionOperation(this, cProperties, path), "shell.properties", path);
	public IOperation EmptyRecycleBin() => mScheduler.Start(new SimulatedActionOperation(this, cEmptyBin, ""), "shell.emptyrecyclebin", "");
	public IOperation Shutdown(bool restart) => mScheduler.Start(new SimulatedActionOperation(this, cPower, restart ? "restart" : "shutdown"), "shell.power", restart ? "restart" : "shutdown");
	public IOperation Lock() => mScheduler.Start(new SimulatedActionOperation(this, cPower, "lock"), "shell.power", "lock");
	public IOperation SignOut() => mScheduler.Start(new SimulatedActionOperation(this, cPower, "signout"), "shell.power", "signout");
}
