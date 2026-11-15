namespace Shell.PlatformWin;

using System;

[CRepr]
struct FILETIME
{
	public uint32 dwLowDateTime;
	public uint32 dwHighDateTime;
}
