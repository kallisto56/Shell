namespace Shell.Rendering;

using System;

// Recycles surfaces by size so that effects do not allocate GPU memory every frame. Surfaces are cleared to transparent when acquired.
// Surfaces not used for a while are released by the pool.
interface IRenderSurfacePool
{
	IRenderSurface Acquire(int width, int height);
	void Release(IRenderSurface surface);
	void BeginFrame();
	void EndFrame();
}
