namespace Shell.Core;

using System;

// Float rectangle (x, y = top-left, Y grows downward) used by layout, clipping and hit testing.
struct RectF
{
	public float mX;
	public float mY;
	public float mWidth;
	public float mHeight;

	public this(float x, float y, float width, float height)
	{
		mX = x;
		mY = y;
		mWidth = width;
		mHeight = height;
	}

	public float mRight => mX + mWidth;
	public float mBottom => mY + mHeight;
	public bool mIsEmpty => mWidth <= 0 || mHeight <= 0;

	public bool Contains(float x, float y)
	{
		return x >= mX && y >= mY && x < mX + mWidth && y < mY + mHeight;
	}

	public RectF Intersection(RectF other)
	{
		let left = Math.Max(mX, other.mX);
		let top = Math.Max(mY, other.mY);
		let right = Math.Min(mRight, other.mRight);
		let bottom = Math.Min(mBottom, other.mBottom);
		if (right <= left || bottom <= top)
			return RectF(left, top, 0, 0);
		return RectF(left, top, right - left, bottom - top);
	}
}
