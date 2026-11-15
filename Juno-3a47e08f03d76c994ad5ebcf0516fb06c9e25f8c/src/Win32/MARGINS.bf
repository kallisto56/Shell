namespace Juno;

using System;
using System.Interop;

[CRepr]
struct MARGINS
{
	public int32 cxLeftWidth;
	public int32 cxRightWidth;
	public int32 cyTopHeight;
	public int32 cyBottomHeight;
}
