namespace Shell.PlatformWin;

using System;

static class NativeKernel32
{
	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 QueryPerformanceCounter(int64* lpPerformanceCount);

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 QueryPerformanceFrequency(int64* lpFrequency);

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public void GetSystemTimeAsFileTime(FILETIME* lpSystemTimeAsFileTime);

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public uint32 GetLastError();

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public void* FindFirstFileW(char16* lpFileName, WIN32_FIND_DATAW* lpFindFileData);

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 FindNextFileW(void* hFindFile, WIN32_FIND_DATAW* lpFindFileData);

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 FindClose(void* hFindFile);

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 CreateDirectoryW(char16* lpPathName, void* lpSecurityAttributes);

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 MoveFileExW(char16* lpExistingFileName, char16* lpNewFileName, uint32 dwFlags);

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public uint32 GetFileAttributesW(char16* lpFileName);

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public void* OpenProcess(uint32 dwDesiredAccess, int32 bInheritHandle, uint32 dwProcessId);

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 CloseHandle(void* hObject);

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 QueryFullProcessImageNameW(void* hProcess, uint32 dwFlags, char16* lpExeName, uint32* lpdwSize);

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public void* GlobalAlloc(uint32 uFlags, uint dwBytes);

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public void* GlobalLock(void* hMem);

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 GlobalUnlock(void* hMem);

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public uint32 GetCurrentProcessId();
}
