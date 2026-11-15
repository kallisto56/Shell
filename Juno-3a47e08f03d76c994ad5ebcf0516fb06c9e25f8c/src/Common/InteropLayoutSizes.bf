namespace Juno;


using System;
using System.Diagnostics;
using System.Interop;


[CRepr]
struct InteropLayoutSizes
{
	public c_uint mJunoDeviceCreateInfo;
	public c_uint mJunoShaderCreateInfo;
	public c_uint mJunoShaderCompileFromFileInfo;
	public c_uint mJunoShaderCompileInfo;
	public c_uint mJunoSwapChainCreateInfo;
	public c_uint mJunoBufferCreateInfo;
	public c_uint mJunoTextureCreateInfo;
	public c_uint mJunoRegion;
	public c_uint mJunoViewport;
	public c_uint mJunoScissor;
	public c_uint mJunoSamplerCreateInfo;
	public c_uint mJunoInputElementDescription;
	public c_uint mJunoBlendDesc;
	public c_uint mJunoRasterizerDesc;
	public c_uint mJunoStencilOpDesc;
	public c_uint mJunoDepthStencilCreateInfo;

	public c_uint mJunoInteropLayoutSizes;
}
