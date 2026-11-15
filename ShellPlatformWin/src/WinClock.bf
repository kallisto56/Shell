namespace Shell.PlatformWin;

using System;
using Shell.Platform;

class WinClock : IClock
{
	int64 mFrequency;
	int64 mStart;

	public this()
	{
		NativeKernel32.QueryPerformanceFrequency(&mFrequency);
		NativeKernel32.QueryPerformanceCounter(&mStart);
	}

	public double GetMonotonicSeconds()
	{
		int64 now = 0;
		NativeKernel32.QueryPerformanceCounter(&now);
		return (double)(now - mStart) / (double)mFrequency;
	}

	// FILETIME counts 100 ns since 1601-01-01; the result counts 100 ns since 0001-01-01 (same unit as .NET ticks).
	public int64 GetUtcTicks()
	{
		FILETIME ft = default;
		NativeKernel32.GetSystemTimeAsFileTime(&ft);
		let fileTime = ((int64)ft.dwHighDateTime << 32) | (int64)ft.dwLowDateTime;
		return fileTime + 504911232000000000;
	}
}
