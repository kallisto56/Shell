namespace Juno;

using System;

// Axis-aligned float rectangle. Origin is the top-left corner, Y grows downward (UI / 2D space).
[CRepr]
struct Rect
{
	public float mX;
	public float mY;
	public float mWidth;
	public float mHeight;

	public this(float x, float y, float width, float height)
	{
		this.mX = x;
		this.mY = y;
		this.mWidth = width;
		this.mHeight = height;
	}

	public float mRight => this.mX + this.mWidth;
	public float mBottom => this.mY + this.mHeight;
	public bool mIsEmpty => this.mWidth <= 0 || this.mHeight <= 0;

	public bool Contains(float x, float y)
	{
		return x >= this.mX && y >= this.mY && x < this.mX + this.mWidth && y < this.mY + this.mHeight;
	}

	public Rect Intersection(Rect other)
	{
		float left = Math.Max(this.mX, other.mX);
		float top = Math.Max(this.mY, other.mY);
		float right = Math.Min(this.mRight, other.mRight);
		float bottom = Math.Min(this.mBottom, other.mBottom);
		if (right <= left || bottom <= top)
			return Rect(left, top, 0, 0);
		return Rect(left, top, right - left, bottom - top);
	}

	public Rect Inflate(float amount)
	{
		return Rect(this.mX - amount, this.mY - amount, this.mWidth + amount * 2, this.mHeight + amount * 2);
	}

	public Rect Deflate(Insets insets)
	{
		return Rect(this.mX + insets.mLeft, this.mY + insets.mTop, this.mWidth - insets.mLeft - insets.mRight, this.mHeight - insets.mTop - insets.mBottom);
	}
}
