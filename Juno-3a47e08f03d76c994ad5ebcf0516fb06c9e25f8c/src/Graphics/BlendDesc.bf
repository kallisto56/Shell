namespace Juno;

using System;
using System.Interop;

[CRepr]
struct BlendDesc
{
	public c_bool bAlphaToCoverage = false;
	public c_bool bBlendEnable = false;
	public BlendFactor mSrcBlend = .One;
	public BlendFactor mDestBlend = .Zero;
	public BlendOp mBlendOp = .Add;
	public BlendFactor mSrcBlendAlpha = .One;
	public BlendFactor mDestBlendAlpha = .Zero;
	public BlendOp mBlendOpAlpha = .Add;
	public ColorWriteMask mWriteMask = .All;
}
