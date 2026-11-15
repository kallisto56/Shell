namespace Juno;

using System;

// Off-screen color (+ optional depth) target that can be sampled afterwards (post-processing etc.).
class RenderTarget
{
	public Device* mDevice;
	public Texture2D mColor ~ delete _;
	public Texture2D mDepth ~ delete _;     // null when created without depth
	public int32 mWidth;
	public int32 mHeight;
	public PixelFormat mFormat;
	public bool bHasDepth;

	static public Result<RenderTarget> Create(Device* device, int width, int height, PixelFormat format = .R8G8B8A8_UNorm, bool withDepth = true)
	{
		let target = new RenderTarget();
		target.mDevice = device;
		target.mFormat = format;
		target.bHasDepth = withDepth;
		if (!target.Build(width, height))
		{
			delete target;
			return .Err;
		}
		return .Ok(target);
	}

	bool Build(int width, int height)
	{
		mWidth = (int32)width;
		mHeight = (int32)height;

		if (Texture2D.Create(mDevice, width, height, mFormat, null, 0, false, .RenderTarget | .ShaderResource) case .Ok(let color))
			mColor = color;
		else
			return false;

		if (bHasDepth)
		{
			if (Texture2D.Create(mDevice, width, height, .D32_Float, null, 0, false, .DepthStencil) case .Ok(let depth))
				mDepth = depth;
			else
				return false;
		}
		return true;
	}

	// Re-creates the textures with a new size (contents are lost). Call when the window is resized.
	public bool Resize(int width, int height)
	{
		if (width == mWidth && height == mHeight)
			return true;
		delete mColor;
		delete mDepth;
		mColor = null;
		mDepth = null;
		return Build(width, height);
	}
}
