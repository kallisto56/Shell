namespace Shell.PlatformWin;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

// The real Windows environment: the same PlatformServices set the simulation provides, over native APIs.
// ITextInputService (IME / TSF) is attached by the widget runtime in Stage 3.
class WindowsPlatform
{
	public OperationLog mOperations = new .() ~ delete _;
	public WinClock mClock = new .() ~ delete _;
	public WinMonitorService mMonitors = new .() ~ delete _;
	public WinWindowTracker mWindows = new .() ~ delete _;
	public WinFileSystemService mFiles ~ delete _;
	public WinApplicationLauncher mLauncher ~ delete _;
	public WinShellIntegration mShell ~ delete _;
	public WinClipboardService mClipboard = new .() ~ delete _;
	public WinNotificationService mNotifications = new .() ~ delete _;
	public PlatformServices mServices = new .() ~ delete _;
	public WindowsPlatformSystem mSystem ~ delete _;

	public this()
	{
		mFiles = new WinFileSystemService(mOperations);
		mLauncher = new WinApplicationLauncher(mOperations);
		mShell = new WinShellIntegration(mOperations);
		mSystem = new WindowsPlatformSystem(this);

		mServices.mClock = mClock;
		mServices.mWindows = mWindows;
		mServices.mMonitors = mMonitors;
		mServices.mFiles = mFiles;
		mServices.mLauncher = mLauncher;
		mServices.mShell = mShell;
		mServices.mNotifications = mNotifications;
		mServices.mClipboard = mClipboard;
	}

	// Call from the host's window procedure on WM_DISPLAYCHANGE, WM_DPICHANGED and WM_SETTINGCHANGE.
	public void NotifyDisplayChanged()
	{
		mMonitors.NotifyDisplayChanged();
	}
}
