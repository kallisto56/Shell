namespace Shell.PlatformWin;

using System;

[CRepr]
struct SHELLEXECUTEINFOW
{
	public uint32 cbSize;
	public uint32 fMask;
	public void* hwnd;
	public char16* lpVerb;
	public char16* lpFile;
	public char16* lpParameters;
	public char16* lpDirectory;
	public int32 nShow;
	public void* hInstApp;
	public void* lpIDList;
	public char16* lpClass;
	public void* hkeyClass;
	public uint32 dwHotKey;
	public void* hIconOrMonitor;
	public void* hProcess;
}
