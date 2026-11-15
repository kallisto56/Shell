#pragma once

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif

#include "pch.h"

#include "Juno.h"

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3dcompiler.lib")
#pragma comment(lib, "dcomp.lib")
#pragma comment(lib, "dxguid.lib")

using Microsoft::WRL::ComPtr;

/* ------------------------------------------------------------------------- */
/* Error helpers (Error.cpp)                                                 */
/* ------------------------------------------------------------------------- */

JUNO_API JunoErrorCode JunoSetFatalErrorHandler(JunoFatalErrorHandlerFunc callback);
JunoErrorCode JunoSetError(JunoErrorCode code, HRESULT hr, const char* pFormat, ...);
/* Maps device removed/reset to JunoErrorCode_DeviceLost, otherwise returns `fallback`. */
JunoErrorCode JunoFailHResult(JunoErrorCode fallback, HRESULT hr, const char* pWhat);

extern JunoFatalErrorHandlerFunc RuntimeFatalError;

#define JUNO_ASSERT(condition) \
if (!(condition)) \
	RuntimeFatalError(#condition, __FILE__, __LINE__);

#define JUNO_REQUIRE_ALLOC(ptr) \
	do { \
		if ((ptr) == nullptr) \
			return JunoSetError(JunoErrorCode_OutOfMemory, S_OK, "Out of memory"); \
	} while (0)

/* ------------------------------------------------------------------------- */
/* Limits                                                                    */
/* ------------------------------------------------------------------------- */

#define JUNO_MAX_SRV_SLOTS 128
#define JUNO_MAX_CB_SLOTS 14
#define JUNO_MAX_SAMPLER_SLOTS 16
#define JUNO_MAX_VB_SLOTS 32
#define JUNO_MAX_UAV_SLOTS 8

/* ------------------------------------------------------------------------- */
/* Enum / struct layout checks. Juno enums are cast straight to D3D11 ones.  */
/* ------------------------------------------------------------------------- */

static_assert((int)JunoUsage_Default == (int)D3D11_USAGE_DEFAULT && (int)JunoUsage_Staging == (int)D3D11_USAGE_STAGING, "Usage mismatch");
static_assert((int)JunoBindFlags_UnorderedAccess == (int)D3D11_BIND_UNORDERED_ACCESS, "BindFlags mismatch");
static_assert((int)JunoCpuAccessFlags_Write == (int)D3D11_CPU_ACCESS_WRITE, "CpuAccess mismatch");
static_assert((int)JunoMapMode_WriteNoOverwrite == (int)D3D11_MAP_WRITE_NO_OVERWRITE, "Map mismatch");
static_assert((int)JunoPrimitiveTopology_TriangleStrip == (int)D3D11_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP, "Topology mismatch");
static_assert((int)JunoBlendFactor_Constant == (int)D3D11_BLEND_BLEND_FACTOR && (int)JunoBlendFactor_SrcAlphaSat == (int)D3D11_BLEND_SRC_ALPHA_SAT, "Blend mismatch");
static_assert((int)JunoBlendOp_Max == (int)D3D11_BLEND_OP_MAX, "BlendOp mismatch");
static_assert((int)JunoComparisonFunc_Always == (int)D3D11_COMPARISON_ALWAYS, "Comparison mismatch");
static_assert((int)JunoStencilOp_Decr == (int)D3D11_STENCIL_OP_DECR, "StencilOp mismatch");
static_assert((int)JunoFillMode_Solid == (int)D3D11_FILL_SOLID && (int)JunoCullMode_Back == (int)D3D11_CULL_BACK, "Raster mismatch");
static_assert((int)JunoFilter_Anisotropic == (int)D3D11_FILTER_ANISOTROPIC, "Filter mismatch");
static_assert((int)JunoAddressMode_MirrorOnce == (int)D3D11_TEXTURE_ADDRESS_MIRROR_ONCE, "Address mismatch");
static_assert((int)JunoPixelFormat_B8G8R8A8_UNorm == (int)DXGI_FORMAT_B8G8R8A8_UNORM && (int)JunoPixelFormat_BC7_UNorm_SRGB == (int)DXGI_FORMAT_BC7_UNORM_SRGB, "Format mismatch");
static_assert(sizeof(JunoViewport) == sizeof(D3D11_VIEWPORT), "Viewport size mismatch");
static_assert(sizeof(JunoRegion) == sizeof(D3D11_RECT), "Region size mismatch");
static_assert(sizeof(JunoScissor) == sizeof(D3D11_RECT), "Scissor size mismatch");

/* ------------------------------------------------------------------------- */
/* Object definitions                                                        */
/* ------------------------------------------------------------------------- */

struct JunoDevice
{
	ComPtr<ID3D11Device> mDevice;
	ComPtr<ID3D11DeviceContext> mContext;
	ComPtr<IDXGIFactory2> mFactory;
	D3D_FEATURE_LEVEL mFeatureLevel = D3D_FEATURE_LEVEL_11_0;
	bool bTearingSupported = false;
};

struct JunoBuffer
{
	ComPtr<ID3D11Buffer> mHandle;
	ComPtr<ID3D11ShaderResourceView> mSRV;
	ComPtr<ID3D11UnorderedAccessView> mUAV;
	JunoBufferCreateInfo mCreateInfo = {};
};

struct JunoTexture
{
	ComPtr<ID3D11Texture2D> mTexture;
	ComPtr<ID3D11ShaderResourceView> mSRV;
	ComPtr<ID3D11RenderTargetView> mRTV;
	ComPtr<ID3D11DepthStencilView> mDSV;
	ComPtr<ID3D11UnorderedAccessView> mUAV;
	JunoTextureCreateInfo mCreateInfo = {};
	bool bOwnedBySwapChain = false;
};

struct JunoImage
{
	unsigned char* mPixels = nullptr;   // Allocated by stb_image, released with stbi_image_free.
	c_uint mWidth = 0;
	c_uint mHeight = 0;
	c_uint mChannels = 0;
	c_uint mRowPitch = 0;
	JunoPixelFormat mFormat = JunoPixelFormat_Unknown;
};

struct JunoSwapChain
{
	JunoDevice* mDevice = nullptr;
	HWND mHwnd = nullptr;
	ComPtr<IDXGISwapChain1> mSwapChain;
	ComPtr<IDCompositionDevice> mDCompDevice;
	ComPtr<IDCompositionTarget> mDCompTarget;
	ComPtr<IDCompositionVisual> mDCompVisual;
	JunoTexture mBackBuffer;
	JunoTexture mDepthBuffer;
	JunoSwapChainCreateInfo mDesc = {};
	UINT mFlags = 0;
	bool bTearing = false;
};

struct JunoSampler { ComPtr<ID3D11SamplerState> mState; };
struct JunoBlob { ComPtr<ID3DBlob> mBlob; };
struct JunoInputLayout { ComPtr<ID3D11InputLayout> mLayout; };
struct JunoBlendState { ComPtr<ID3D11BlendState> mState; };
struct JunoRasterizerState { ComPtr<ID3D11RasterizerState> mState; };
struct JunoDepthStencilState { ComPtr<ID3D11DepthStencilState> mState; };
struct JunoFence { ComPtr<ID3D11Query> mQuery; };

struct JunoShader
{
	JunoShaderStage mStage = JunoShaderStage_Vertex;
	ComPtr<ID3D11DeviceChild> mShader;
};

/* ------------------------------------------------------------------------- */
/* Stage dispatch helpers                                                    */
/* ------------------------------------------------------------------------- */

inline void JunoBindConstantBuffers(ID3D11DeviceContext* pCtx, JunoShaderStage stage, UINT start, UINT count, ID3D11Buffer* const* ppBuffers)
{
	switch (stage)
	{
	case JunoShaderStage_Vertex: pCtx->VSSetConstantBuffers(start, count, ppBuffers); break;
	case JunoShaderStage_Pixel: pCtx->PSSetConstantBuffers(start, count, ppBuffers); break;
	case JunoShaderStage_Geometry: pCtx->GSSetConstantBuffers(start, count, ppBuffers); break;
	case JunoShaderStage_Compute: pCtx->CSSetConstantBuffers(start, count, ppBuffers); break;
	default: assert(false); break;
	}
}

inline void JunoBindShaderResources(ID3D11DeviceContext* pCtx, JunoShaderStage stage, UINT start, UINT count, ID3D11ShaderResourceView* const* ppViews)
{
	switch (stage)
	{
	case JunoShaderStage_Vertex: pCtx->VSSetShaderResources(start, count, ppViews); break;
	case JunoShaderStage_Pixel: pCtx->PSSetShaderResources(start, count, ppViews); break;
	case JunoShaderStage_Geometry: pCtx->GSSetShaderResources(start, count, ppViews); break;
	case JunoShaderStage_Compute: pCtx->CSSetShaderResources(start, count, ppViews); break;
	default: assert(false); break;
	}
}

inline void JunoBindSamplers(ID3D11DeviceContext* pCtx, JunoShaderStage stage, UINT start, UINT count, ID3D11SamplerState* const* ppSamplers)
{
	switch (stage)
	{
	case JunoShaderStage_Vertex: pCtx->VSSetSamplers(start, count, ppSamplers); break;
	case JunoShaderStage_Pixel: pCtx->PSSetSamplers(start, count, ppSamplers); break;
	case JunoShaderStage_Geometry: pCtx->GSSetSamplers(start, count, ppSamplers); break;
	case JunoShaderStage_Compute: pCtx->CSSetSamplers(start, count, ppSamplers); break;
	default: assert(false); break;
	}
}
