namespace Shell.Render;

using System;
using System.Collections;
using Juno;
using Shell.Core;
using Shell.Elements;
using Shell.Rendering;

// Everything the built-in effect passes need: the graphics object, the surface pool and lazily created shaders / constant buffers.
class JunoEffectContext : IEffectContext
{
	[CRepr]
	public struct BlurConstants
	{
		public float mDirX;
		public float mDirY;
		public float mTexelX;
		public float mTexelY;
		public float mRadius;
		public float mPad0;
		public float mPad1;
		public float mPad2;
	}

	[CRepr]
	public struct ShadowConstants
	{
		public float mR;
		public float mG;
		public float mB;
		public float mA;
	}

	public Graphics mGraphics;
	public JunoSurfacePool mPool;
	DiagnosticSink mSink;
	public ShaderProgram mBlurShader ~ delete _;
	public ConstantBuffer mBlurConstants ~ delete _;
	public ShaderProgram mShadowShader ~ delete _;
	public ConstantBuffer mShadowConstants ~ delete _;
	bool bBlurFailed;
	bool bShadowFailed;

	public this(Graphics graphics, JunoSurfacePool pool, DiagnosticSink sink)
	{
		mGraphics = graphics;
		mPool = pool;
		mSink = sink;
	}

	public IRenderSurfacePool GetPool() => mPool;

	public bool EnsureBlur()
	{
		if (mBlurShader != null)
			return true;
		if (bBlurFailed)
			return false;
		let source = scope String();
		EffectShaders.BuildBlur(source);
		if (ShaderProgram.Create(mGraphics.mDevice, source, mGraphics.mVertexLayout, "ShellBlur") case .Ok(let program))
			mBlurShader = program;
		if (ConstantBuffer.Create(mGraphics.mDevice, sizeof(BlurConstants)) case .Ok(let buffer))
			mBlurConstants = buffer;
		if (mBlurShader == null || mBlurConstants == null)
		{
			bBlurFailed = true;
			if (mSink != null)
				mSink.Error("REN0011", "The blur shader could not be created.");
			return false;
		}
		return true;
	}

	public bool EnsureShadow()
	{
		if (mShadowShader != null)
			return true;
		if (bShadowFailed)
			return false;
		let source = scope String();
		EffectShaders.BuildShadow(source);
		if (ShaderProgram.Create(mGraphics.mDevice, source, mGraphics.mVertexLayout, "ShellShadow") case .Ok(let program))
			mShadowShader = program;
		if (ConstantBuffer.Create(mGraphics.mDevice, sizeof(ShadowConstants)) case .Ok(let buffer))
			mShadowConstants = buffer;
		if (mShadowShader == null || mShadowConstants == null)
		{
			bShadowFailed = true;
			if (mSink != null)
				mSink.Error("REN0012", "The shadow shader could not be created.");
			return false;
		}
		return true;
	}
}
