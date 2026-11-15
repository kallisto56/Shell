namespace Shell.Core;

using System;

// Version of the saved format. Major changes are incompatible (a migration is required), minor changes are
// additive (older readers can still load, unknown fields are preserved).
struct SchemaVersion
{
	public uint16 mMajor;
	public uint16 mMinor;

	public this(uint16 major, uint16 minor)
	{
		mMajor = major;
		mMinor = minor;
	}

	static public bool operator ==(SchemaVersion a, SchemaVersion b) => a.mMajor == b.mMajor && a.mMinor == b.mMinor;
	static public bool operator !=(SchemaVersion a, SchemaVersion b) => !(a == b);

	public bool IsNewerThan(SchemaVersion other)
	{
		return (mMajor > other.mMajor) || (mMajor == other.mMajor && mMinor > other.mMinor);
	}

	public void ToString(String outString)
	{
		outString.AppendF("{}.{}", mMajor, mMinor);
	}
}
