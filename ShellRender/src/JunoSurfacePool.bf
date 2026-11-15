namespace Shell.Render;

using System;
using System.Collections;
using Juno;
using Shell.Core;
using Shell.Elements;
using Shell.Rendering;

// Render-target pool. Sizes are rounded up to a multiple of 32 so that animated groups keep reusing the same targets; a surface
// that was not used for 120 frames is destroyed. Surfaces are cleared to transparent when handed out.
// Surfaces are R8G8B8A8 without depth, premultiplied alpha by convention (content is drawn with alpha blending onto transparent black).
class JunoSurfacePool : IRenderSurfacePool
{
	const int cGranularity = 32;
	const int cMaxIdleFrames = 120;
	const int cMaxSize = 8192;

	Graphics mGraphics;
	List<JunoSurface> mSurfaces = new .() ~ DeleteContainerAndItems!(_);
	public DiagnosticSink mSink;
	public int mInUse;

	public this(Graphics graphics, DiagnosticSink sink)
	{
		mGraphics = graphics;
		mSink = sink;
	}

	static int Round(int value) => ((Math.Max(value, 1) + cGranularity - 1) / cGranularity) * cGranularity;

	public IRenderSurface Acquire(int width, int height)
	{
		let w = Math.Min(Round(width), cMaxSize);
		let h = Math.Min(Round(height), cMaxSize);

		JunoSurface found = null;
		for (let surface in mSurfaces)
		{
			if (!surface.bInUse && surface.mWidth == w && surface.mHeight == h)
			{
				found = surface;
				break;
			}
		}

		if (found == null)
		{
			if (RenderTarget.Create(mGraphics.mDevice, w, h, .R8G8B8A8_UNorm, false) case .Ok(let target))
			{
				found = new JunoSurface();
				found.mTarget = target;
				found.mWidth = w;
				found.mHeight = h;
				mSurfaces.Add(found);
			}
			else
			{
				if (mSink != null)
					mSink.Error("REN0010", scope $"A {w}x{h} render surface could not be created.");
				return null;
			}
		}

		found.bInUse = true;
		found.mIdleFrames = 0;
		mInUse++;

		mGraphics.PushRenderTarget(found.mTarget);
		mGraphics.Clear(Color(0, 0, 0, 0));
		mGraphics.PopRenderTarget();
		return found;
	}

	public void Release(IRenderSurface surface)
	{
		let juno = surface as JunoSurface;
		if (juno != null && juno.bInUse)
		{
			juno.bInUse = false;
			mInUse--;
		}
	}

	public void BeginFrame()
	{
	}

	public void EndFrame()
	{
		for (var i = mSurfaces.Count - 1; i >= 0; i--)
		{
			let surface = mSurfaces[i];
			if (surface.bInUse)
				continue;
			surface.mIdleFrames++;
			if (surface.mIdleFrames > cMaxIdleFrames)
			{
				mSurfaces.RemoveAt(i);
				delete surface;
			}
		}
	}
}
