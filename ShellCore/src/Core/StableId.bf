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
