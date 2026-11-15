namespace Shell.PlatformWin;

using System;

[CRepr]
struct SHFILEOPSTRUCTW
{
	public void* hwnd;
	public uint32 wFunc;
	public char16* pFrom;
	public char16* pTo;
	public uint16 fFlags;
	public int32 fAnyOperationsAborted;
	public void* hNameMappings;
	public char16* lpszProgressTitle;
}
