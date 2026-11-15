namespace Shell.PlatformWin;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

// FindFirstFileW / FindNextFileW wrapper. Returns 0 on success or the Windows error code.
static class WinFind
{
	static public uint32 Enumerate(StringView folder, List<FoundEntry> output)
	{
		let pattern = scope String(folder);
		pattern.Replace('/', '\\');
		if (!pattern.EndsWith('\\'))
			pattern.Append('\\');
		pattern.Append('*');

		let wide = scope List<char16>();
		WideString.Encode(pattern, wide);

		WIN32_FIND_DATAW data = default;
		let handle = NativeKernel32.FindFirstFileW(wide.Ptr, &data);
		if (handle == (void*)((int)-1))
			return NativeKernel32.GetLastError();

		repeat
		{
			let entry = new FoundEntry();
			WideString.Decode(&data.cFileName[0], entry.mName, 260);
			if (entry.mName == "." || entry.mName == "..")
			{
				delete entry;
				continue;
			}
			entry.mAttributes = data.dwFileAttributes;
			entry.mSize = ((uint64)data.nFileSizeHigh << 32) | (uint64)data.nFileSizeLow;
			let ft = ((int64)data.ftLastWriteTime.dwHighDateTime << 32) | (int64)data.ftLastWriteTime.dwLowDateTime;
			entry.mModifiedUtcTicks = ft + 504911232000000000;
			output.Add(entry);
		}
		while (NativeKernel32.FindNextFileW(handle, &data) != 0);

		NativeKernel32.FindClose(handle);
		return 0;
	}
}
