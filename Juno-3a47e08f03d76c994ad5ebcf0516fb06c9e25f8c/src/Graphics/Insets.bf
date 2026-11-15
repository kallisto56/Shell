namespace Juno;

using System;

[CRepr]
struct Insets
{
	public float mLeft;
	public float mTop;
	public float mRight;
	public float mBottom;

	public this(float left, float top, float right, float bottom)
	{
		this.mLeft = left;
		this.mTop = top;
		this.mRight = right;
		this.mBottom = bottom;
	}

	public this(float all)
	{
		this.mLeft = all;
		this.mTop = all;
		this.mRight = all;
		this.mBottom = all;
	}
}
