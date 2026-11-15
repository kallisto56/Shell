namespace Shell.PlatformWin;

using System;

static class NativeShcore
{
	[Import("SHCORE.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 GetDpiForMonitor(void* hmonitor, int32 dpiType, uint32* dpiX, uint32* dpiY);
}
