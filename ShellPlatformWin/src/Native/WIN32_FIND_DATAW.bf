namespace Shell.PlatformWin;

using System;

[CRepr]
struct WIN32_FIND_DATAW
{
	public uint32 dwFileAttributes;
	public FILETIME ftCreationTime;
	public FILETIME ftLastAccessTime;
	public FILETIME ftLastWriteTime;
	public uint32 nFileSizeHigh;
	public uint32 nFileSizeLow;
	public uint32 dwReserved0;
	public uint32 dwReserved1;
	public char16[260] cFileName;
	public char16[14] cAlternateFileName;
}
