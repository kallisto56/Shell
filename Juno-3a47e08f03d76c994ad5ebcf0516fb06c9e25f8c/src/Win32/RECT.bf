namespace Juno;

using System;
using System.Interop;

[CRepr]
struct RECT
{
	public LONG left;
	public LONG top;
	public LONG right;
	public LONG bottom;
}
