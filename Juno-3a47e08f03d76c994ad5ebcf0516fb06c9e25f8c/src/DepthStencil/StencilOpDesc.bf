namespace Juno;

using System;
using System.Interop;

[CRepr]
struct StencilOpDesc
{
	public StencilOp mStencilFailOp = .Keep;
	public StencilOp mStencilDepthFailOp = .Keep;
	public StencilOp mStencilPassOp = .Keep;
	public ComparisonFunc mStencilFunc = .Always;
}
