namespace Shell.Platform;

using System;

// Opaque identifier of a window of another application (HWND in the real shell, a virtual id in the simulation).
struct NativeWindowId : IHashable
{
	public uint64 mValue;

	public bool mIsValid => mValue != 0;
	static public bool operator ==(NativeWindowId a, NativeWindowId b) => a.mValue == b.mValue;
	static public bool operator !=(NativeWindowId a, NativeWindowId b) => a.mValue != b.mValue;


	public int GetHashCode()
	{
		return (.)this.mValue;
	}
}
