namespace Juno;

using System;
using System.Interop;

extension NativeMethods
{
	[Import("SHELL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public UINT ExtractIconExW(LPCWSTR lpszFile, int32 nIconIndex, HICON* phiconLarge, HICON* phiconSmall, UINT nIcons);
}
