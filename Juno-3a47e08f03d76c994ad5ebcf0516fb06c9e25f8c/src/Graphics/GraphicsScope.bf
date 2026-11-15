namespace Juno;

using System;

// Returned by Graphics.Push*(). Dispose() restores the previous state, so
//     using (g.PushClip(rect)) { ... }
// works as well as an explicit Graphics.Pop*() call.
struct GraphicsScope : IDisposable
{
	public enum Kind
	{
		case Transform;
		case Tint;
		case Clip;
		case Shader;
		case RenderTarget;
	}

	Graphics mGraphics;
	Kind mKind;

	public this(Graphics graphics, Kind kind)
	{
		this.mGraphics = graphics;
		this.mKind = kind;
	}

	public void Dispose()
	{
		switch (this.mKind)
		{
		case .Transform: this.mGraphics.PopTransform();
		case .Tint: this.mGraphics.PopTint();
		case .Clip: this.mGraphics.PopClip();
		case .Shader: this.mGraphics.PopShader();
		case .RenderTarget: this.mGraphics.PopRenderTarget();
		}
	}
}
