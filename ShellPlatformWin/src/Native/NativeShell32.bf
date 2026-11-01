namespace Shell.PlatformWin;

using System;

static class NativeShell32
{
	[Import("SHELL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 SHFileOperationW(SHFILEOPSTRUCTW* lpFileOp);

	[Import("SHELL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 ShellExecuteExW(SHELLEXECUTEINFOW* pExecInfo);

	[Import("SHELL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 SHGetKnownFolderPath(GUID* rfid, uint32 dwFlags, void* hToken, char16** ppszPath);

	[Import("SHELL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 SHEmptyRecycleBinW(void* hwnd, char16* pszRootPath, uint32 dwFlags);

	[Import("SHELL32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public uint SHAppBarMessage(uint32 dwMessage, APPBARDATA* pData);
}
