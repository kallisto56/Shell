namespace Juno;

using System;

// One glyph atlas page (RGBA8: white + coverage in alpha, so the normal shaders can draw it) with a shelf packer.
class FontPage
{
	public Texture2D mTexture ~ delete _;
	public int32 mSize;
	int32 mCursorX;
	int32 mCursorY;
	int32 mRowHeight;

	public this(int32 size)
	{
		this.mSize = size;
	}

	// Reserves a w x h rectangle (1 px padding). Returns false when the page is full.
	public bool TryPack(int w, int h, out int x, out int y)
	{
		x = 0;
		y = 0;
		let pw = w + 1;
		let ph = h + 1;
		if (pw > mSize || ph > mSize)
			return false;

		if (mCursorX + pw > mSize)
		{
			mCursorY += mRowHeight;
			mCursorX = 0;
			mRowHeight = 0;
		}
		if (mCursorY + ph > mSize)
			return false;

		x = mCursorX;
		y = mCursorY;
		mCursorX += (int32)pw;
		mRowHeight = Math.Max(mRowHeight, (int32)ph);
		return true;
	}
}
