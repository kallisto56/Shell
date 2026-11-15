namespace Juno;

using System;
using System.Collections;

// UTF-8 -> UTF-16 helper for the W-suffixed Win32 functions.
static class Wide
{
	// Appends the UTF-16 encoding of `str` plus a null terminator to `outBuf`. Use outBuf.Ptr as LPCWSTR.
	static public void Encode(StringView str, List<char16> outBuf)
	{
		for (let c in str.DecodedChars)
		{
			uint32 cp = (uint32)c;
			if (cp >= 0x10000)
			{
				cp -= 0x10000;
				outBuf.Add((char16)(0xD800 + (cp >> 10)));
				outBuf.Add((char16)(0xDC00 + (cp & 0x3FF)));
			}
			else
			{
				outBuf.Add((char16)cp);
			}
		}
		outBuf.Add((char16)0);
	}
}
