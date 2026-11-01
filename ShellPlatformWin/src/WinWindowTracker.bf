namespace Shell.PlatformWin;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

// Tracks top-level windows of other applications by polling EnumWindows (robust, no hooks or extra message loop needed).
// The platform system calls Poll() about every 100 ms; the tracker diffs against the previous snapshot and raises
// created / destroyed / changed / activated events.
//
// A window is a taskbar candidate when it is visible, has a title, has no owner and is not a tool window. Cloaked windows
// (other virtual desktops, suspended UWP apps) are reported with the Cloaked flag so the shell can hide them.
// Windows owned by this process are flagged ShellOwned and must not be listed as applications.
class WinWindowTracker : IWindowTracker
{
	List<TrackedWindow> mWindows = new .() ~ DeleteContainerAndItems!(_);       // current snapshot, z-order front to back
	List<TrackedWindow> mScratch = new .() ~ DeleteContainerAndItems!(_);       // being built by Poll
	Dictionary<uint32, String> mProcessNames = new .() ~ DeleteDictionaryAndValues!(_);
	IWindowTrackerListener mListener;
	uint32 mOwnProcess;
	void* mForeground;
	int mZCounter;

	public Dictionary<uint64, RectF> mTaskbarButtons = new .() ~ delete _;

	public this()
	{
		mOwnProcess = NativeKernel32.GetCurrentProcessId();
	}

	[CallingConvention(.Stdcall)]
	static int32 EnumCallback(void* hWnd, int data)
	{
		let tracker = (WinWindowTracker)Internal.UnsafeCastToObject((void*)data);
		tracker.Consider(hWnd);
		return 1;
	}

	void Consider(void* hWnd)
	{
		let z = mZCounter++;
		if (NativeUser32.IsWindowVisible(hWnd) == 0)
			return;
		if (NativeUser32.GetWindow(hWnd, 4) != null)        // GW_OWNER
			return;

		let exStyle = NativeUser32.GetWindowLongPtrW(hWnd, -20);    // GWL_EXSTYLE
		let bTool = (exStyle & 0x80) != 0;                  // WS_EX_TOOLWINDOW
		let length = NativeUser32.GetWindowTextLengthW(hWnd);
		if (length <= 0)
			return;

		let window = new TrackedWindow();
		window.mId = NativeWindowId() { mValue = (uint64)(int)hWnd };
		window.mZOrder = z;

		let buffer = scope List<char16>();
		for (int i < length + 1)
			buffer.Add((char16)0);
		NativeUser32.GetWindowTextW(hWnd, buffer.Ptr, (int32)(length + 1));
		WideString.Decode(buffer.Ptr, window.mTitle, length);

		uint32 processId = 0;
		NativeUser32.GetWindowThreadProcessId(hWnd, &processId);
		window.mProcessId = processId;
		window.mApplicationId.Set(GetProcessName(processId));

		RECT rect = default;
		NativeUser32.GetWindowRect(hWnd, &rect);
		window.mBounds = RectF((float)rect.left, (float)rect.top, (float)(rect.right - rect.left), (float)(rect.bottom - rect.top));

		let monitor = NativeUser32.MonitorFromWindow(hWnd, 2);      // MONITOR_DEFAULTTONEAREST
		window.mMonitor = (uint32)(int)monitor;

		var flags = TrackedWindowFlags.Visible;
		if (bTool) flags |= .ToolWindow;
		if (NativeUser32.IsIconic(hWnd) != 0) flags |= .Minimized;
		if (NativeUser32.IsZoomed(hWnd) != 0) flags |= .Maximized;
		if (hWnd == mForeground) flags |= .Active;
		if (processId == mOwnProcess) flags |= .ShellOwned;

		int32 cloaked = 0;
		NativeDwmapi.DwmGetWindowAttribute(hWnd, 14, &cloaked, 4);   // DWMWA_CLOAKED
		if (cloaked != 0) flags |= .Cloaked;
		window.mFlags = flags;
		mScratch.Add(window);
	}

	String GetProcessName(uint32 processId)
	{
		if (mProcessNames.TryGetValue(processId, let cached))
			return cached;

		let name = new String();
		let process = NativeKernel32.OpenProcess(0x1000, 0, processId);     // PROCESS_QUERY_LIMITED_INFORMATION
		if (process != null)
		{
			char16[1024] path = default;
			uint32 size = 1024;
			if (NativeKernel32.QueryFullProcessImageNameW(process, 0, &path[0], &size) != 0)
				WideString.Decode(&path[0], name, (int)size);
			NativeKernel32.CloseHandle(process);
		}
		mProcessNames[processId] = name;
		return name;
	}

	static bool Same(TrackedWindow a, TrackedWindow b)
	{
		return a.mTitle == b.mTitle && a.mFlags == b.mFlags && a.mBounds.mX == b.mBounds.mX && a.mBounds.mY == b.mBounds.mY
			&& a.mBounds.mWidth == b.mBounds.mWidth && a.mBounds.mHeight == b.mBounds.mHeight && a.mMonitor == b.mMonitor;
	}

	// Takes a new snapshot and raises events for the differences.
	public void Poll()
	{
		mScratch.ClearAndDeleteItems();
		mZCounter = 0;
		mForeground = NativeUser32.GetForegroundWindow();
		NativeUser32.EnumWindows(=> EnumCallback, (int)Internal.UnsafeCastToPtr(this));

		let previous = scope List<TrackedWindow>();
		previous.AddRange(mWindows);
		mWindows.Clear();
		mWindows.AddRange(mScratch);
		mScratch.Clear();       // ownership moved to mWindows

		if (mListener != null)
		{
			for (let window in mWindows)
			{
				TrackedWindow old = null;
				for (let candidate in previous)
				{
					if (candidate.mId == window.mId)
					{
						old = candidate;
						break;
					}
				}
				if (old == null)
					mListener.OnWindowCreated(window);
				else
				{
					if (!Same(old, window)) mListener.OnWindowChanged(window);
					if ((window.mFlags & .Active) != 0 && (old.mFlags & .Active) == 0) mListener.OnWindowActivated(window.mId);
				}
			}
			for (let old in previous)
			{
				bool bFound = false;
				for (let window in mWindows)
				{
					if (window.mId == old.mId)
						bFound = true;
				}
				if (!bFound)
					mListener.OnWindowDestroyed(old.mId);
			}
		}

		// The previous snapshot is no longer needed (listeners must not keep the pointers past the callback).
		for (let old in previous)
			delete old;
	}

	// ---- IWindowTracker ----

	public void GetWindows(List<TrackedWindow> output) => output.AddRange(mWindows);
	public void SetListener(IWindowTrackerListener listener) { mListener = listener; }

	static void* Handle(NativeWindowId id) => (void*)(int)id.mValue;

	public void Activate(NativeWindowId id)
	{
		let hWnd = Handle(id);
		if (NativeUser32.IsIconic(hWnd) != 0)
			NativeUser32.ShowWindow(hWnd, 9);               // SW_RESTORE
		NativeUser32.SetForegroundWindow(hWnd);
	}

	public void Minimize(NativeWindowId id) { NativeUser32.ShowWindow(Handle(id), 6); }     // SW_MINIMIZE
	public void Restore(NativeWindowId id) { NativeUser32.ShowWindow(Handle(id), 9); }      // SW_RESTORE
	public void Maximize(NativeWindowId id) { NativeUser32.ShowWindow(Handle(id), 3); }     // SW_MAXIMIZE

	// Asks the window to close (WM_CLOSE). The application may refuse, e.g. to ask about unsaved work.
	public void Close(NativeWindowId id) { NativeUser32.PostMessageW(Handle(id), 0x0010, 0, 0); }

	public void SetBounds(NativeWindowId id, RectF bounds)
	{
		// SWP_NOZORDER | SWP_NOACTIVATE
		NativeUser32.SetWindowPos(Handle(id), null, (int32)bounds.mX, (int32)bounds.mY, (int32)bounds.mWidth, (int32)bounds.mHeight, 0x0004 | 0x0010);
	}

	public void SetTaskbarButtonBounds(NativeWindowId id, RectF bounds)
	{
		mTaskbarButtons[id.mValue] = bounds;
	}
}
