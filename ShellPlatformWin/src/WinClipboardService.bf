namespace Shell.PlatformWin;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

class WinClipboardService : IClipboardService
{
	const uint32 cUnicodeText = 13;

	public bool GetText(String output)
	{
		if (NativeUser32.OpenClipboard(null) == 0)
			return false;
		defer NativeUser32.CloseClipboard();

		let handle = NativeUser32.GetClipboardData(cUnicodeText);
		if (handle == null)
			return false;
		let wide = (char16*)NativeKernel32.GlobalLock(handle);
		if (wide == null)
			return false;
		WideString.Decode(wide, output);
		NativeKernel32.GlobalUnlock(handle);
		return true;
	}

	public void SetText(StringView text)
	{
		let wide = scope List<char16>();
		WideString.Encode(text, wide);

		let memory = NativeKernel32.GlobalAlloc(0x2, (uint)(wide.Count * 2));     // GMEM_MOVEABLE
		if (memory == null)
			return;
		let destination = (char16*)NativeKernel32.GlobalLock(memory);
		if (destination == null)
			return;
		for (int i < wide.Count)
			destination[i] = wide[i];
		NativeKernel32.GlobalUnlock(memory);

		if (NativeUser32.OpenClipboard(null) == 0)
			return;
		NativeUser32.EmptyClipboard();
		NativeUser32.SetClipboardData(cUnicodeText, memory);   // the clipboard owns the memory now
		NativeUser32.CloseClipboard();
	}
}
