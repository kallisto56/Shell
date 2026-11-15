namespace Shell.PlatformWin;

using System;

static class NativeInput
{
	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public void* SetCapture(void* hWnd);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 ReleaseCapture();

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public void* SetCursor(void* hCursor);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public void* LoadCursorW(void* hInstance, char16* lpCursorName);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int DefWindowProcW(void* hWnd, uint32 Msg, uint wParam, int lParam);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 ScreenToClient(void* hWnd, POINT* lpPoint);

	[Import("USER32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 ClientToScreen(void* hWnd, POINT* lpPoint);
}
