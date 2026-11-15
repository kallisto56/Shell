namespace Shell.Runtime;

using System;

// UTF-8 helpers for byte-offset based text editing. Invalid sequences decode as U+FFFD, one byte at a time.
static class Utf8
{
	static public uint32 Decode(StringView text, int index, out int length)
	{
		length = 1;
		let b0 = (uint32)(uint8)text[index];
		if (b0 < 0x80)
			return b0;

		int count;
		uint32 cp;
		if ((b0 & 0xE0) == 0xC0) { count = 1; cp = b0 & 0x1F; }
		else if ((b0 & 0xF0) == 0xE0) { count = 2; cp = b0 & 0x0F; }
		else if ((b0 & 0xF8) == 0xF0) { count = 3; cp = b0 & 0x07; }
		else return 0xFFFD;

		for (int i = 1; i <= count; i++)
		{
			if (index + i >= text.Length)
				return 0xFFFD;
			let b = (uint32)(uint8)text[index + i];
			if ((b & 0xC0) != 0x80)
				return 0xFFFD;
			cp = (cp << 6) | (b & 0x3F);
		}
		length = count + 1;
		return cp;
	}

	// Start of the code point that ends at `index` (index > 0).
	static public int PreviousStart(StringView text, int index)
	{
		var i = index - 1;
		while (i > 0 && ((uint8)text[i] & 0xC0) == 0x80)
			i--;
		return i;
	}

	static public int CodePointCount(StringView text)
	{
		int count = 0;
		var i = 0;
		while (i < text.Length)
		{
			Decode(text, i, var length);
			i += length;
			count++;
		}
		return count;
	}

	// UTF-16 code unit offset of a byte offset.
	static public int ToUtf16(StringView text, int byteIndex)
	{
		int units = 0;
		var i = 0;
		while (i < byteIndex && i < text.Length)
		{
			let cp = Decode(text, i, var length);
			i += length;
			units += (cp >= 0x10000) ? 2 : 1;
		}
		return units;
	}

	// Byte offset of a UTF-16 offset. A position inside a surrogate pair snaps to the start of the code point.
	static public int FromUtf16(StringView text, int utf16Index)
	{
		int units = 0;
		var i = 0;
		while (i < text.Length)
		{
			let cp = Decode(text, i, var length);
			let width = (cp >= 0x10000) ? 2 : 1;
			if (units + width > utf16Index)
				return i;
			units += width;
			i += length;
		}
		return text.Length;
	}

	static public int Utf16Length(StringView text) => ToUtf16(text, text.Length);
}
