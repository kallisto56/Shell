namespace Juno;

using System;
using System.Interop;

[CRepr]
struct Viewport
{
	public float mTopLeftX = 0;
	public float mTopLeftY = 0;
	public float mWidth = 0;
	public float mHeight = 0;
	public float mMinDepth = 0;
	public float mMaxDepth = 1;
}
