namespace Shell.Simulation;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

// Simulated desktop windows of "other applications". Behaves like a small window manager: z-order, activation,
// minimize/maximize/restore, bounds, close. Everything is data; nothing reaches the host's windows.
class VirtualWindowManager : IWindowTracker
{
	List<TrackedWindow> mWindows = new .() ~ DeleteContainerAndItems!(_);       // index 0 = topmost
	public IWindowTrackerListener mListener;
	uint64 mNextId = 1;

	public Dictionary<NativeWindowId, RectF> mTaskbarButtons = new .() ~ delete _;   // as reported by the shell UI

	public int mCount => mWindows.Count;

	public NativeWindowId CreateWindow(StringView title, StringView applicationId, RectF bounds, uint32 processId = 1, TrackedWindowFlags extraFlags = .None)
	{
		let window = new TrackedWindow();
		window.mId = NativeWindowId() { mValue = mNextId++ };
		window.mTitle.Set(title);
		window.mApplicationId.Set(applicationId);
		window.mProcessId = processId;
		window.mBounds = bounds;
		window.mFlags = .Visible | extraFlags;
		mWindows.Insert(0, window);
		Renumber();
		SetActive(window);
		if (mListener != null)
			mListener.OnWindowCreated(window);
		return window.mId;
	}

	TrackedWindow Find(NativeWindowId id)
	{
		for (let window in mWindows)
		{
			if (window.mId == id)
				return window;
		}
		return null;
	}

	void Renumber()
	{
		for (int i < mWindows.Count)
			mWindows[i].mZOrder = i;
	}

	void SetActive(TrackedWindow active)
	{
		for (let window in mWindows)
		{
			if (window == active) window.mFlags |= .Active;
			else window.mFlags = (TrackedWindowFlags)((uint16)window.mFlags & ~(uint16)TrackedWindowFlags.Active);
		}
	}

	void Changed(TrackedWindow window)
	{
		if (mListener != null)
			mListener.OnWindowChanged(window);
	}

	// ---- IWindowTracker ----

	public void GetWindows(List<TrackedWindow> output)
	{
		output.AddRange(mWindows);
	}

	public void SetListener(IWindowTrackerListener listener)
	{
		mListener = listener;
	}

	public void Activate(NativeWindowId id)
	{
		let window = Find(id);
		if (window == null)
			return;

		window.mFlags = (TrackedWindowFlags)((uint16)window.mFlags & ~(uint16)TrackedWindowFlags.Minimized);
		mWindows.Remove(window);
		mWindows.Insert(0, window);
		Renumber();
		SetActive(window);
		Changed(window);
		if (mListener != null)
			mListener.OnWindowActivated(id);
	}

	public void Minimize(NativeWindowId id)
	{
		let window = Find(id);
		if (window == null)
			return;
		window.mFlags = (TrackedWindowFlags)(((uint16)window.mFlags | (uint16)TrackedWindowFlags.Minimized) & ~(uint16)TrackedWindowFlags.Active);
		Changed(window);

		// Like Windows: the next visible window becomes active.
		for (let other in mWindows)
		{
			if (other != window && (other.mFlags & .Minimized) == 0 && (other.mFlags & .Visible) != 0)
			{
				Activate(other.mId);
				break;
			}
		}
	}

	public void Restore(NativeWindowId id)
	{
		let window = Find(id);
		if (window == null)
			return;
		window.mFlags = (TrackedWindowFlags)((uint16)window.mFlags & ~((uint16)TrackedWindowFlags.Minimized | (uint16)TrackedWindowFlags.Maximized));
		Activate(id);
	}

	public void Maximize(NativeWindowId id)
	{
		let window = Find(id);
		if (window == null)
			return;
		window.mFlags |= .Maximized;
		Activate(id);
	}

	public void Close(NativeWindowId id)
	{
		let window = Find(id);
		if (window == null)
			return;
		mWindows.Remove(window);
		Renumber();
		mTaskbarButtons.Remove(id);
		if (mListener != null)
			mListener.OnWindowDestroyed(id);
		delete window;

		if (mWindows.Count > 0 && (mWindows[0].mFlags & .Minimized) == 0)
			Activate(mWindows[0].mId);
	}

	public void SetBounds(NativeWindowId id, RectF bounds)
	{
		let window = Find(id);
		if (window == null)
			return;
		window.mBounds = bounds;
		Changed(window);
	}

	public void SetTaskbarButtonBounds(NativeWindowId id, RectF bounds)
	{
		mTaskbarButtons[id] = bounds;
	}

	// ---- Snapshots ----

	public void CopyFrom(VirtualWindowManager other)
	{
		mWindows.ClearAndDeleteItems();
		mTaskbarButtons.Clear();
		for (let source in other.mWindows)
		{
			let copy = new TrackedWindow();
			copy.mId = source.mId;
			copy.mTitle.Set(source.mTitle);
			copy.mApplicationId.Set(source.mApplicationId);
			copy.mProcessId = source.mProcessId;
			copy.mBounds = source.mBounds;
			copy.mMonitor = source.mMonitor;
			copy.mFlags = source.mFlags;
			copy.mZOrder = source.mZOrder;
			mWindows.Add(copy);
		}
		for (let entry in other.mTaskbarButtons)
			mTaskbarButtons[entry.key] = entry.value;
		mNextId = other.mNextId;
	}
}
