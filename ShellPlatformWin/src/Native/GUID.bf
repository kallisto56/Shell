namespace Shell.PlatformWin;

using System;

[CRepr]
struct GUID
{
	public uint32 Data1;
	public uint16 Data2;
	public uint16 Data3;
	public uint8[8] Data4;
}
