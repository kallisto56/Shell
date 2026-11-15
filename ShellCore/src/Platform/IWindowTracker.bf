namespace Shell.Platform;

using System;
using System.Collections;
using Shell.Core;

// Observes and controls the windows of other applications. The shell coexists with normal Windows applications: only
// windows reported here that are not ShellOwned are candidates for taskbar items.
interface IWindowTracker
{
	// Fills `output` with the tracker's current snapshot, front to back. The TrackedWindow objects are owned by the tracker
	// and valid until the next snapshot (Poll / next frame); do not delete them or keep them across frames.
	void GetWindows(List<TrackedWindow> output);
	void SetListener(IWindowTrackerListener listener);
	void Activate(NativeWindowId id);
	void Minimize(NativeWindowId id);
	void Restore(NativeWindowId id);
	void Maximize(NativeWindowId id);
	void Close(NativeWindowId id);                  // asks the window to close (WM_CLOSE), never terminates the process
	void SetBounds(NativeWindowId id, RectF bounds);
	// Screen rectangle of the window's taskbar button, supplied by the shell, used by native minimize/restore animation hints.
	void SetTaskbarButtonBounds(NativeWindowId id, RectF bounds);
}
