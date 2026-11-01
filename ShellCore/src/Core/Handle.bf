namespace Shell.Core;

using System;

// Runtime reference to a live object: slot index + generation. A handle becomes stale when its object is
// destroyed (the generation changes), so resolving it returns null instead of a dangling pointer.
// Handles are never serialized; saved files use StableId.
struct Handle : IHashable
{
	public uint32 mIndex;
	public uint32 mGeneration;      // 0 = invalid

	static public Handle sNone = Handle(0, 0);

	public this(uint32 index, uint32 generation)
	{
		mIndex = index;
		mGeneration = generation;
	}

	public bool mIsValid => mGeneration != 0;

	static public bool operator ==(Handle a, Handle b) => a.mIndex == b.mIndex && a.mGeneration == b.mGeneration;
	static public bool operator !=(Handle a, Handle b) => !(a == b);

	public int GetHashCode()
	{
		return (int)(mIndex * 31 + mGeneration);
	}

	public int64 Pack()
	{
		return (int64)(((uint64)mGeneration << 32) | (uint64)mIndex);
	}

	static public Handle Unpack(int64 packed)
	{
		return Handle((uint32)((uint64)packed & 0xFFFFFFFF), (uint32)((uint64)packed >> 32));
	}
}
