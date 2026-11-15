namespace Shell.PlatformWin;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

// Monitors via EnumDisplayMonitors + GetDpiForMonitor (per-monitor effective DPI, Windows 8.1+). The host calls
// NotifyDisplayChanged() from WM_DISPLAYCHANGE / WM_DPICHANGED / WM_SETTINGCHANGE; the service re-enumerates and informs
// its listener. ReserveWorkArea registers the shell's taskbar as an application desktop toolbar (appbar), so maximized
// windows of other applications stop at the taskbar.
class WinMonitorService : IMonitorService
{
	List<MonitorInfo> mMonitors = new .() ~ DeleteContainerAndItems!(_);
	IMonitorListener mListener;
	public void* mAppBarWindow;             // HWND of the taskbar window (set by the host before ReserveWorkArea)
	bool bAppBarRegistered;

	public this()
	{
		Refresh();
	}

	[CallingConvention(.Stdcall)]
	static int32 EnumCallback(void* hMonitor, void* hdc, RECT* rect, int data)
	{
		let service = (WinMonitorService)Internal.UnsafeCastToObject((void*)data);
		service.AddMonitor(hMonitor);
		return 1;
	}

	void AddMonitor(void* hMonitor)
	{
		MONITORINFOEXW info = default;
		info.cbSize = (uint32)sizeof(MONITORINFOEXW);
		if (NativeUser32.GetMonitorInfoW(hMonitor, &info) == 0)
			return;

		let monitor = new MonitorInfo();
		monitor.mId = (uint32)(mMonitors.Count + 1);
		WideString.Decode(&info.szDevice[0], monitor.mName, 32);
		monitor.mBounds = RectF((float)info.rcMonitor.left, (float)info.rcMonitor.top, (float)(info.rcMonitor.right - info.rcMonitor.left), (float)(info.rcMonitor.bottom - info.rcMonitor.top));
		monitor.mWorkArea = RectF((float)info.rcWork.left, (float)info.rcWork.top, (float)(info.rcWork.right - info.rcWork.left), (float)(info.rcWork.bottom - info.rcWork.top));
		monitor.bPrimary = (info.dwFlags & 1) != 0;     // MONITORINFOF_PRIMARY

		uint32 dpiX = 96;
		uint32 dpiY = 96;
		NativeShcore.GetDpiForMonitor(hMonitor, 0, &dpiX, &dpiY);   // MDT_EFFECTIVE_DPI
		monitor.mDpiScale = (float)dpiX / 96.0f;
		mMonitors.Add(monitor);
	}

	public void Refresh()
	{
		mMonitors.ClearAndDeleteItems();
		NativeUser32.EnumDisplayMonitors(null, null, => EnumCallback, (int)Internal.UnsafeCastToPtr(this));
	}

	public void NotifyDisplayChanged()
	{
		Refresh();
		if (mListener != null)
			mListener.OnMonitorsChanged();
	}

	public void GetMonitors(List<MonitorInfo> output) => output.AddRange(mMonitors);
	public void SetListener(IMonitorListener listener) { mListener = listener; }

	static uint32 EdgeOf(RectF area, RectF monitor)
	{
		// ABE_LEFT 0, ABE_TOP 1, ABE_RIGHT 2, ABE_BOTTOM 3
		if (area.mWidth >= area.mHeight)
			return (area.mY <= monitor.mY + 1) ? 1 : 3;
		return (area.mX <= monitor.mX + 1) ? 0 : 2;
	}

	public void ReserveWorkArea(uint32 monitor, RectF area)
	{
		if (mAppBarWindow == null)
			return;

		MonitorInfo target = null;
		for (let m in mMonitors)
		{
			if (m.mId == monitor)
				target = m;
		}
		if (target == null)
			return;

		APPBARDATA data = default;
		data.cbSize = (uint32)sizeof(APPBARDATA);
		data.hWnd = mAppBarWindow;
		if (!bAppBarRegistered)
		{
			NativeShell32.SHAppBarMessage(0, &data);        // ABM_NEW
			bAppBarRegistered = true;
		}

		data.uEdge = EdgeOf(area, target.mBounds);
		data.rc.left = (int32)area.mX;
		data.rc.top = (int32)area.mY;
		data.rc.right = (int32)area.mRight;
		data.rc.bottom = (int32)area.mBottom;
		NativeShell32.SHAppBarMessage(2, &data);            // ABM_QUERYPOS: let the system adjust the rectangle
		NativeShell32.SHAppBarMessage(3, &data);            // ABM_SETPOS: reserve it
		NotifyDisplayChanged();
	}

	public void ReleaseWorkArea(uint32 monitor)
	{
		if (!bAppBarRegistered)
			return;
		APPBARDATA data = default;
		data.cbSize = (uint32)sizeof(APPBARDATA);
		data.hWnd = mAppBarWindow;
		NativeShell32.SHAppBarMessage(1, &data);            // ABM_REMOVE
		bAppBarRegistered = false;
		NotifyDisplayChanged();
	}
}
