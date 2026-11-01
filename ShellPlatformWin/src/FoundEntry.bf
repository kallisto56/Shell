namespace Shell.PlatformWin;

using System;

class FoundEntry
{
	public String mName = new .() ~ delete _;
	public uint32 mAttributes;
	public uint64 mSize;
	public int64 mModifiedUtcTicks;

	public bool mIsDirectory => (mAttributes & 0x10) != 0;
}
