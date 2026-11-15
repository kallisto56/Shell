namespace Shell.PlatformWin;

using System;

static class NativeUser32
{
	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 EnumWindows(WNDENUMPROC lpEnumFunc, int lParam);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 IsWindowVisible(void* hWnd);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 IsIconic(void* hWnd);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 IsZoomed(void* hWnd);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 GetWindowTextW(void* hWnd, char16* lpString, int32 nMaxCount);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 GetWindowTextLengthW(void* hWnd);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int GetWindowLongPtrW(void* hWnd, int32 nIndex);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public void* GetWindow(void* hWnd, uint32 uCmd);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public uint32 GetWindowThreadProcessId(void* hWnd, uint32* lpdwProcessId);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 GetWindowRect(void* hWnd, RECT* lpRect);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public void* GetForegroundWindow();

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 SetForegroundWindow(void* hWnd);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 ShowWindow(void* hWnd, int32 nCmdShow);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 PostMessageW(void* hWnd, uint32 Msg, uint wParam, int lParam);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 SetWindowPos(void* hWnd, void* hWndInsertAfter, int32 X, int32 Y, int32 cx, int32 cy, uint32 uFlags);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public void* MonitorFromWindow(void* hWnd, uint32 dwFlags);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 EnumDisplayMonitors(void* hdc, RECT* lprcClip, MONITORENUMPROC lpfnEnum, int dwData);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 GetMonitorInfoW(void* hMonitor, MONITORINFOEXW* lpmi);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 LockWorkStation();

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 ExitWindowsEx(uint32 uFlags, uint32 dwReason);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 OpenClipboard(void* hWndNewOwner);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 CloseClipboard();

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 EmptyClipboard();

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public void* GetClipboardData(uint32 uFormat);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public void* SetClipboardData(uint32 uFormat, void* hMem);
}
