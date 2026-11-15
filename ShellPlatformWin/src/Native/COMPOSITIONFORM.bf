namespace Shell.PlatformWin;

using System;

[CRepr]
struct COMPOSITIONFORM
{
	public uint32 dwStyle;
	public POINT ptCurrentPos;
	public RECT rcArea;
}
