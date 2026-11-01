namespace Shell.Platform;

using System;
using Shell.Core;

// The set of platform services of one environment (real Windows shell or simulation). Every member may be null when
// the environment does not provide it; consumers must handle that with a diagnostic, not a crash.
// Not owned: the environment (Windows host or simulation) owns the implementations.
class PlatformServices
{
	public IClock mClock;
	public IWindowTracker mWindows;
	public IMonitorService mMonitors;
	public IFileSystemService mFiles;
	public IApplicationLauncher mLauncher;
	public IShellIntegration mShell;
	public INotificationService mNotifications;
	public IClipboardService mClipboard;
	public ITextInputService mTextInput;
}
