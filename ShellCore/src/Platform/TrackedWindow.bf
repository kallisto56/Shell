namespace Shell.Platform;

using System;
using Shell.Core;

class TrackedWindow
{
	public NativeWindowId mId;
	public String mTitle = new .() ~ delete _;
	public String mApplicationId = new .() ~ delete _;      // executable path or AppUserModelID
	public uint32 mProcessId;
	public RectF mBounds;                                   // physical pixels, virtual-screen coordinates
	public uint32 mMonitor;
	public TrackedWindowFlags mFlags;
	public int mZOrder;                                     // 0 = topmost
}
