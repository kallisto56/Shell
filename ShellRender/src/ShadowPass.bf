namespace Shell.Render;

using System;
using System.Collections;
using Juno;
using Shell.Core;
using Shell.Elements;
using Shell.Rendering;

// Drop shadow and glow: the blurred silhouette of the content, tinted, drawn behind the content.
//   DropShadow parameters: [0] blur radius (default 8), [1] offset as Vector2 (default 0, 4), [2] color (default black, 50 %)
//   Glow       parameters: [0] blur radius (default 8), [1] color (default white);   no offset
class ShadowPass : IEffectPass
{
	EffectKind mKind;

	public this(EffectKind kind)
	{
		mKind = kind;
	}

	public EffectKind GetKind() => mKind;
	public StringView GetCustomName() => default;

	float Radius(EffectDescriptor effect)
	{
		return (effect.mParameters.Count > 0) ? Math.Clamp((float)effect.mParameters[0].AsFloat(8), 0, 64) : 8.0f;
	}

	PointF Offset(EffectDescriptor effect)
	{
		if (mKind == .Glow)
			return default;
		if (effect.mParameters.Count > 1)
			return PointF(effect.mParameters[1].mX, effect.mParameters[1].mY);
		return PointF(0, 4);
	}

	Value ShadowColor(EffectDescriptor effect)
	{
		let index = (mKind == .Glow) ? 1 : 2;
		if (effect.mParameters.Count > index)
			return effect.mParameters[index];
		return (mKind == .Glow) ? Value.FromColor(1, 1, 1, 1) : Value.FromColor(0, 0, 0, 0.5f);
	}

	public float GetPadding(EffectDescriptor effect)
	{
		let offset = Offset(effect);
		return Math.Ceiling(Radius(effect) * 2 + Math.Max(Math.Abs(offset.mX), Math.Abs(offset.mY)));
	}

	public IRenderSurface Apply(IEffectContext effectContext, IRenderSurface source, EffectDescriptor effect)
	{
		let context = (JunoEffectContext)effectContext;
		let input = source as JunoSurface;
		if (input == null || !context.EnsureShadow())
			return source;

		let g = context.mGraphics;
		let blurred = BlurPass.Blur(context, source, Radius(effect)) as JunoSurface;
		let output = context.mPool.Acquire(input.mWidth, input.mHeight) as JunoSurface;
		if (blurred == null || output == null)
		{
			if (blurred != null && blurred != input) context.mPool.Release(blurred);
			if (output != null) context.mPool.Release(output);
			return source;
		}

		let color = ShadowColor(effect);
		JunoEffectContext.ShadowConstants constants = default;
		constants.mR = color.mX;
		constants.mG = color.mY;
		constants.mB = color.mZ;
		constants.mA = color.mW;
		context.mShadowConstants.Update(constants);

		let offset = Offset(effect);
		g.PushRenderTarget(output.mTarget);

		// 1. tinted silhouette, offset
		g.SetShader(context.mShadowShader);
		g.SetConstantBuffer(0, context.mShadowConstants);
		g.SetBlendMode(.Premultiplied);
		g.DrawTexture(blurred.mTarget.mColor, offset.mX, offset.mY, (float)output.mWidth, (float)output.mHeight);
		g.Flush();
		g.SetShader(null);

		// 2. the content itself on top
		g.DrawTexture(input.mTarget.mColor, 0, 0, (float)output.mWidth, (float)output.mHeight);
		g.Flush();
		g.SetBlendMode(.Alpha);
		g.PopRenderTarget();

		if (blurred != input)
			context.mPool.Release(blurred);
		return output;
	}
}
