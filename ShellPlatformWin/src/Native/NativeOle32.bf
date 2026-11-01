namespace Shell.PlatformWin;

using System;

static class NativeOle32
{
	[Import("OLE32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public void CoTaskMemFree(void* pv);
}
