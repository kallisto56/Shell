namespace Shell.Core;

using System;

// Identifier of a serializable object. It is stored in saved files and survives save/load, copy/paste,
// reordering and renaming. 64 random bits, written as 16 lowercase hex digits. 0 is "no id".
struct StableId : IHashable
{
	public uint64 mValue;

	static public StableId sNone = StableId(0);

	public this(uint64 value)
	{
		mValue = value;
	}

	public bool mIsValid => mValue != 0;

	// Deterministic id derived from two ids (SplitMix64 finalizer). Used for objects created from templates: the same template
	// node under the same owner always gets the same id, however often the subtree is destroyed and re-created.
	static public StableId Combine(StableId a, StableId b)
	{
		uint64 z = a.mValue * 0x9E3779B97F4A7C15 + b.mValue + 0x7F4A7C15;
		z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9;
		z = (z ^ (z >> 27)) * 0x94D049BB133111EB;
		z = z ^ (z >> 31);
		return StableId((z != 0) ? z : 1);
	}

	static public bool operator ==(StableId a, StableId b) => a.mValue == b.mValue;
	static public bool operator !=(StableId a, StableId b) => a.mValue != b.mValue;

	public int GetHashCode()
	{
		return (int)(mValue ^ (mValue >> 32));
	}

	public void ToString(String outString)
	{
		let digits = "0123456789abcdef";
		for (int i = 15; i >= 0; i--)
			outString.Append(digits[(int)((mValue >> (uint64)(i * 4)) & 0xF)]);
	}

	// Exactly 16 hex digits (upper or lower case).
	static public Result<StableId> Parse(StringView text)
	{
		if (text.Length != 16)
			return .Err;

		uint64 value = 0;
		for (let c in text)
		{
			uint64 digit = 0;
			if (c >= '0' && c <= '9') digit = (uint64)(c - '0');
			else if (c >= 'a' && c <= 'f') digit = (uint64)(c - 'a') + 10;
			else if (c >= 'A' && c <= 'F') digit = (uint64)(c - 'A') + 10;
			else return .Err;
			value = (value << 4) | digit;
		}
		return .Ok(StableId(value));
	}
}
