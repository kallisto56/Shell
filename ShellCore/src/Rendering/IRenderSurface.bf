namespace Shell.Rendering;

using System;

// Off-screen pixel storage used for subtree compositing and effect passes. The renderer implements it on top of GPU render targets.
interface IRenderSurface
{
	int GetWidth();
	int GetHeight();
}
