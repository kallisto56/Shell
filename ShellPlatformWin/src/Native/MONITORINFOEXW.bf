namespace Shell.PlatformWin;

using System;

[CRepr]
struct MONITORINFOEXW
{
	public uint32 cbSize;
	public RECT rcMonitor;
	public RECT rcWork;
	public uint32 dwFlags;
	public char16[32] szDevice;
}
