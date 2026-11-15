namespace Shell.Render;

using System;
using System.Collections;
using Juno;
using Shell.Core;
using Shell.Elements;
using Shell.Rendering;

// Gaussian blur. Parameters: [0] radius in pixels (default 8). The surface needs 2 * radius of padding on every side.
class BlurPass : IEffectPass
{
	public EffectKind GetKind() => .Blur;
	public StringView GetCustomName() => default;

	static float Radius(EffectDescriptor effect)
	{
		return (effect.mParameters.Count > 0) ? Math.Clamp((float)effect.mParameters[0].AsFloat(8), 0, 64) : 8.0f;
	}

	public float GetPadding(EffectDescriptor effect) => Math.Ceiling(Radius(effect) * 2);

	// Two passes (horizontal into a temporary surface, vertical into the result). Returns a new surface; `source` stays untouched.
	static public IRenderSurface Blur(JunoEffectContext context, IRenderSurface source, float radius)
	{
		let input = source as JunoSurface;
		if (input == null || radius < 0.5f || !context.EnsureBlur())
			return source;

		//let g = context.mGraphics;
		let w = input.mWidth;
		let h = input.mHeight;
		let temp = context.mPool.Acquire(w, h) as JunoSurface;
		let output = context.mPool.Acquire(w, h) as JunoSurface;
		if (temp == null || output == null)
		{
			if (temp != null) context.mPool.Release(temp);
			if (output != null) context.mPool.Release(output);
			return source;
		}

		RunDirection(context, input, temp, 1, 0, radius);
		RunDirection(context, temp, output, 0, 1, radius);
		context.mPool.Release(temp);
		return output;
	}

	static void RunDirection(JunoEffectContext context, JunoSurface from, JunoSurface to, float dirX, float dirY, float radius)
	{
		let g = context.mGraphics;
		BlurConstants constants = default;
		constants.mDirX = dirX;
		constants.mDirY = dirY;
		constants.mTexelX = 1.0f / (float)from.mWidth;
		constants.mTexelY = 1.0f / (float)from.mHeight;
		constants.mRadius = radius;
		context.mBlurConstants.Update(constants);

		g.PushRenderTarget(to.mTarget);
		g.SetShader(context.mBlurShader);
		g.SetConstantBuffer(0, context.mBlurConstants);
		g.SetBlendMode(.Opaque);
		g.DrawTexture(from.mTarget.mColor, 0, 0, (float)to.mWidth, (float)to.mHeight);
		g.Flush();
		g.SetShader(null);
		g.SetBlendMode(.Alpha);
		g.PopRenderTarget();
	}

	typealias BlurConstants = JunoEffectContext.BlurConstants;

	public IRenderSurface Apply(IEffectContext context, IRenderSurface source, EffectDescriptor effect)
	{
		return Blur((JunoEffectContext)context, source, Radius(effect));
	}
}
