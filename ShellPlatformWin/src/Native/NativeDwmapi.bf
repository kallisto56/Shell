namespace Shell.PlatformWin;

using System;

static class NativeDwmapi
{
	[Import("DWMAPI.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 DwmGetWindowAttribute(void* hwnd, uint32 dwAttribute, void* pvAttribute, uint32 cbAttribute);
}
