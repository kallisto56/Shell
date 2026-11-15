namespace Juno;

using System;
using System.Interop;

[CRepr]
struct RasterizerDesc
{
	public FillMode mFillMode = .Solid;
	public CullMode mCullMode = .Back;
	public c_int mDepthBias = 0;
	public float mDepthBiasClamp = 0;
	public float mSlopeScaledDepthBias = 0;
	public c_bool bFrontCounterClockwise = false;
	public c_bool bDepthClipEnable = true;
	public c_bool bScissorEnable = false;
	public c_bool bMultisampleEnable = false;
	public c_bool bAntialiasedLineEnable = false;
}
