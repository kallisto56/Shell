namespace Shell.PlatformWin;

using System;

[CRepr]
struct CANDIDATEFORM
{
	public uint32 dwIndex;
	public uint32 dwStyle;
	public POINT ptCurrentPos;
	public RECT rcArea;
}
