namespace Juno;


using System;
using System.Diagnostics;
using System.Interop;


[CRepr]
struct Scissor
{
	public c_int mLeft;
	public c_int mTop;
	public c_int mRight;
	public c_int mBottom;

	public this(c_int left, c_int top, c_int right, c_int bottom)
	{
		mLeft = left;
		mTop = top;
		mRight = right;
		mBottom = bottom;
	}
}
