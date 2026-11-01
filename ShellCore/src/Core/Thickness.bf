namespace Shell.Core;

using System;

struct Thickness
{
	public float mLeft;
	public float mTop;
	public float mRight;
	public float mBottom;

	public this(float left, float top, float right, float bottom)
	{
		mLeft = left;
		mTop = top;
		mRight = right;
		mBottom = bottom;
	}

	public this(float all)
	{
		mLeft = all;
		mTop = all;
		mRight = all;
		mBottom = all;
	}

	public float mHorizontal => mLeft + mRight;
	public float mVertical => mTop + mBottom;
}
