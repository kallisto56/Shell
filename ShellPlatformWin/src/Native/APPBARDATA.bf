namespace Shell.PlatformWin;

using System;

[CRepr]
struct APPBARDATA
{
	public uint32 cbSize;
	public void* hWnd;
	public uint32 uCallbackMessage;
	public uint32 uEdge;
	public RECT rc;
	public int lParam;
}
