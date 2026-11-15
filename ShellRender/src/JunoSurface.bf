namespace Shell.Render;

using System;
using Juno;
using Shell.Rendering;

class JunoSurface : IRenderSurface
{
	public RenderTarget mTarget ~ delete _;
	public int mWidth;
	public int mHeight;
	public bool bInUse;
	public int mIdleFrames;

	public int GetWidth() => mWidth;
	public int GetHeight() => mHeight;
}
