namespace Shell.Platform;

using System;

interface IWindowTrackerListener
{
	void OnWindowCreated(TrackedWindow window);
	void OnWindowDestroyed(NativeWindowId id);
	void OnWindowChanged(TrackedWindow window);     // title, bounds, state
	void OnWindowActivated(NativeWindowId id);
}
