namespace Shell.Platform;

using System;
using Shell.Core;

class MonitorInfo
{
	public uint32 mId;
	public String mName = new .() ~ delete _;
	public RectF mBounds;           // physical pixels, virtual-screen coordinates
	public RectF mWorkArea;         // bounds minus areas reserved by appbars (including this shell's taskbar)
	public float mDpiScale;         // 1.0 = 96 dpi
	public bool bPrimary;
}
