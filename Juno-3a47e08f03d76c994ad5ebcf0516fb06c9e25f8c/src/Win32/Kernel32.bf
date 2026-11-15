namespace Juno;

using System;
using System.Interop;

extension NativeMethods
{
	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public HMODULE GetModuleHandleW(LPCWSTR lpModuleName);

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public HMODULE GetModuleHandleA(char8* lpModuleName);

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public void* GetProcAddress(HMODULE hModule, char8* lpProcName);

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public DWORD GetModuleFileNameW(HMODULE hModule, char16* lpFilename, DWORD nSize);

	[Import("KERNEL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public DWORD GetLastError();
}
