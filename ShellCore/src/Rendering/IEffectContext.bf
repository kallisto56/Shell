namespace Shell.Rendering;

using System;

// Services an effect pass can use. The concrete context of the GPU renderer offers more (drawing into a surface, shaders); passes
// that need it cast to that type.
interface IEffectContext
{
	IRenderSurfacePool GetPool();
}
