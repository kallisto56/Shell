namespace Shell.PlatformWin;

using System;
using System.Collections;

// UTF-8 <-> UTF-16 conversion for the W-suffixed Win32 functions.
static class WideString
{
	// Appends the UTF-16 form of `text` plus a null terminator.
	static public void Encode(StringView text, List<char16> output)
	{
		for (let c in text.DecodedChars)
		{
			var cp = (uint32)c;
			if (cp >= 0x10000)
			{
				cp -= 0x10000;
				output.Add((char16)(0xD800 + (cp >> 10)));
				output.Add((char16)(0xDC00 + (cp & 0x3FF)));
			}
			else
			{
				output.Add((char16)cp);
			}
		}
		output.Add((char16)0);
	}

	// Appends the UTF-8 form of a null-terminated or fixed-length (maxLength) UTF-16 string.
	static public void Decode(char16* text, String output, int maxLength = 32768)
	{
		var i = 0;
		while (i < maxLength && text[i] != 0)
		{
			uint32 cp = (uint32)text[i];
			i++;
			if (cp >= 0xD800 && cp <= 0xDBFF && i < maxLength && text[i] >= 0xDC00 && text[i] <= 0xDFFF)
			{
				cp = 0x10000 + ((cp - 0xD800) << 10) + ((uint32)text[i] - 0xDC00);
				i++;
			}
			output.Append((char32)cp);
		}
	}

	// Double-null-terminated list used by SHFileOperation: "a\0b\0\0".
	static public void EncodeList(List<String> paths, List<char16> output)
	{
		for (let path in paths)
		{
			let converted = scope String(path);
			converted.Replace('/', '\\');
			for (let c in converted.DecodedChars)
				output.Add((char16)c);
			output.Add((char16)0);
		}
		output.Add((char16)0);
	}
}
