namespace Juno;

using System;
using System.Interop;

extension NativeMethods
{
	[CRepr]
	public struct MONITORINFOEXW
	{
	    public c_uint cbSize;
	    public RECT rcMonitor;
	    public RECT rcWork;
	    public c_uint dwFlags;
	    public c_wchar[32] szDevice; 
	}

	[AllowDuplicates]
	public enum MonitorDefaults : c_uint
	{
	    MONITOR_DEFAULTTONULL = 0x00000000,
	    MONITOR_DEFAULTTOPRIMARY = 0x00000001,
	    MONITOR_DEFAULTTONEAREST = 0x00000002
	}

	public enum SystemMetric : c_int
	{
	    SM_CXSCREEN = 0,
	    SM_CYSCREEN = 1
	}

	[AllowDuplicates]
	public enum SetWindowPosFlags : c_uint
	{
	    SWP_NOSIZE = 0x0001,
	    SWP_NOMOVE = 0x0002,
	    SWP_NOZORDER = 0x0004,
	    SWP_NOACTIVATE = 0x0010,
	    SWP_SHOWWINDOW = 0x0040
	}

	[Import("USER32.dll"), CLink, CallingConvention(.Stdcall)]
	public static extern c_int GetSystemMetrics(SystemMetric smIndex);

	[Import("USER32.dll"), CLink, CallingConvention(.Stdcall)]
	public static extern HWND MonitorFromWindow(HWND hwnd, MonitorDefaults dwFlags);

	[Import("USER32.dll"), CLink, CallingConvention(.Stdcall)]
	public static extern c_bool GetMonitorInfoW(HWND hMonitor, MONITORINFOEXW* lpmi);

	[Import("USER32.dll"), CLink, CallingConvention(.Stdcall)]
	public static extern c_bool GetWindowRect(HWND hWnd, out RECT lpRect);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public ATOM RegisterClassExW(WNDCLASSEXW* lpWndClass);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public BOOL UnregisterClassW(LPCWSTR lpClassName, HINSTANCE hInstance);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public HWND CreateWindowExW(DWORD dwExStyle, LPCWSTR lpClassName, LPCWSTR lpWindowName, DWORD dwStyle, int32 X, int32 Y, int32 nWidth, int32 nHeight, HWND hWndParent, HMENU hMenu, HINSTANCE hInstance, void* lpParam);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public BOOL DestroyWindow(HWND hWnd);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public BOOL IsWindow(HWND hWnd);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public BOOL ShowWindow(HWND hWnd, SHOW_WINDOW_COMMAND nCmdShow);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public BOOL UpdateWindow(HWND hWnd);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public BOOL SetWindowTextW(HWND hWnd, LPCWSTR lpString);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public BOOL GetClientRect(HWND hWnd, RECT* lpRect);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public BOOL GetWindowRect(HWND hWnd, RECT* lpRect);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public BOOL AdjustWindowRectEx(RECT* lpRect, DWORD dwStyle, BOOL bMenu, DWORD dwExStyle);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public BOOL SetWindowPos(HWND hWnd, HWND hWndInsertAfter, int32 X, int32 Y, int32 cx, int32 cy, SET_WINDOW_POS_FLAGS uFlags);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public LRESULT DefWindowProcW(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public BOOL PeekMessageW(MSG* lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, PEEK_MESSAGE_FLAGS wRemoveMsg);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public BOOL TranslateMessage(MSG* lpMsg);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public LRESULT DispatchMessageW(MSG* lpMsg);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public void PostQuitMessage(int32 nExitCode);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public BOOL PostMessageW(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public LRESULT SendMessageW(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int SetWindowLongPtrW(HWND hWnd, WINDOW_LONG_INDEX nIndex, int dwNewLong);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int GetWindowLongPtrW(HWND hWnd, WINDOW_LONG_INDEX nIndex);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public BOOL SetLayeredWindowAttributes(HWND hwnd, COLORREF crKey, BYTE bAlpha, LAYERED_WINDOW_ATTRIBUTES dwFlags);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public void* LoadImageW(HINSTANCE hInst, LPCWSTR name, IMAGE_TYPE type, int32 cx, int32 cy, LOAD_IMAGE_FLAGS fuLoad);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public HCURSOR LoadCursorW(HINSTANCE hInstance, LPCWSTR lpCursorName);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public HCURSOR SetCursor(HCURSOR hCursor);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public BOOL DestroyIcon(HICON hIcon);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public BOOL SetProcessDPIAware();

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public BOOL SetProcessDpiAwarenessContext(void* value);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public UINT GetDpiForWindow(HWND hwnd);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int16 GetAsyncKeyState(int32 vKey);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public HWND SetCapture(HWND hWnd);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public BOOL ReleaseCapture();
}
