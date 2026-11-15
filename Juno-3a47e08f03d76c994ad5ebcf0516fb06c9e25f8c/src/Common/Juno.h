#pragma once

#include "Interop.h"

#ifdef __cplusplus
#define JUNO_API extern "C" __declspec(dllexport)
#else
#define JUNO_API __declspec(dllexport)
#endif

#define JUNO_APPEND_ALIGNED_ELEMENT 0xFFFFFFFFu
#define JUNO_MAX_RENDER_TARGETS 8

/* ------------------------------------------------------------------------- */
/* Opaque handles                                                            */
/* ------------------------------------------------------------------------- */

typedef struct JunoDevice JunoDevice;
typedef struct JunoSwapChain JunoSwapChain;
typedef struct JunoBuffer JunoBuffer;
typedef struct JunoTexture JunoTexture;
typedef struct JunoImage JunoImage;
typedef struct JunoSampler JunoSampler;
typedef struct JunoBlob JunoBlob;
typedef struct JunoShader JunoShader;
typedef struct JunoInputLayout JunoInputLayout;
typedef struct JunoBlendState JunoBlendState;
typedef struct JunoRasterizerState JunoRasterizerState;
typedef struct JunoDepthStencilState JunoDepthStencilState;
typedef struct JunoFence JunoFence;

/* ------------------------------------------------------------------------- */
/* Callbacks                                                                 */
/* ------------------------------------------------------------------------- */

typedef void (*JunoFatalErrorHandlerFunc)(const char* message, const char* file, c_int line);

/* ------------------------------------------------------------------------- */
/* Enums. Values of most enums match the D3D11/DXGI ones and are cast        */
/* directly (see static_asserts in JunoInternal.h).                          */
/* ------------------------------------------------------------------------- */

typedef enum JunoErrorCode
{
	JunoErrorCode_Ok = 0,
	JunoErrorCode_InvalidArgument,
	JunoErrorCode_OutOfMemory,
	JunoErrorCode_DeviceCreationFailed,
	JunoErrorCode_DeviceLost,
	JunoErrorCode_SwapChainCreationFailed,
	JunoErrorCode_SwapChainResizeFailed,
	JunoErrorCode_PresentFailed,
	JunoErrorCode_BufferCreationFailed,
	JunoErrorCode_TextureCreationFailed,
	JunoErrorCode_StateCreationFailed,
	JunoErrorCode_ShaderCompileFailed,
	JunoErrorCode_ShaderCreationFailed,
	JunoErrorCode_InputLayoutCreationFailed,
	JunoErrorCode_FenceCreationFailed,
	JunoErrorCode_MapFailed,
	JunoErrorCode_FileNotFound,
	JunoErrorCode_Unsupported,
	JunoErrorCode_ImageLoadFailed,
	JunoErrorCode_Unknown,
} JunoErrorCode;

typedef enum JunoPixelFormat
{
	JunoPixelFormat_Unknown = 0,
	JunoPixelFormat_R32G32B32A32_Float = 2,
	JunoPixelFormat_R32G32B32A32_UInt = 3,
	JunoPixelFormat_R32G32B32A32_SInt = 4,
	JunoPixelFormat_R32G32B32_Float = 6,
	JunoPixelFormat_R32G32B32_UInt = 7,
	JunoPixelFormat_R32G32B32_SInt = 8,
	JunoPixelFormat_R16G16B16A16_Float = 10,
	JunoPixelFormat_R16G16B16A16_UNorm = 11,
	JunoPixelFormat_R32G32_Float = 16,
	JunoPixelFormat_R32G32_UInt = 17,
	JunoPixelFormat_R32G32_SInt = 18,
	JunoPixelFormat_R10G10B10A2_UNorm = 24,
	JunoPixelFormat_R11G11B10_Float = 26,
	JunoPixelFormat_R8G8B8A8_Typeless = 27,
	JunoPixelFormat_R8G8B8A8_UNorm = 28,
	JunoPixelFormat_R8G8B8A8_UNorm_SRGB = 29,
	JunoPixelFormat_R8G8B8A8_UInt = 30,
	JunoPixelFormat_R16G16_Float = 34,
	JunoPixelFormat_R16G16_UNorm = 35,
	JunoPixelFormat_R32_Typeless = 39,
	JunoPixelFormat_D32_Float = 40,
	JunoPixelFormat_R32_Float = 41,
	JunoPixelFormat_R32_UInt = 42,
	JunoPixelFormat_R32_SInt = 43,
	JunoPixelFormat_R24G8_Typeless = 44,
	JunoPixelFormat_D24_UNorm_S8_UInt = 45,
	JunoPixelFormat_R8G8_UNorm = 49,
	JunoPixelFormat_R16_Typeless = 53,
	JunoPixelFormat_R16_Float = 54,
	JunoPixelFormat_D16_UNorm = 55,
	JunoPixelFormat_R16_UNorm = 56,
	JunoPixelFormat_R16_UInt = 57,
	JunoPixelFormat_R8_UNorm = 61,
	JunoPixelFormat_R8_UInt = 62,
	JunoPixelFormat_A8_UNorm = 65,
	JunoPixelFormat_BC1_UNorm = 71,
	JunoPixelFormat_BC1_UNorm_SRGB = 72,
	JunoPixelFormat_BC3_UNorm = 77,
	JunoPixelFormat_BC3_UNorm_SRGB = 78,
	JunoPixelFormat_BC4_UNorm = 80,
	JunoPixelFormat_BC5_UNorm = 83,
	JunoPixelFormat_B8G8R8A8_UNorm = 87,
	JunoPixelFormat_B8G8R8X8_UNorm = 88,
	JunoPixelFormat_B8G8R8A8_UNorm_SRGB = 91,
	JunoPixelFormat_BC7_UNorm = 98,
	JunoPixelFormat_BC7_UNorm_SRGB = 99,
} JunoPixelFormat;

typedef enum JunoUsage
{
	JunoUsage_Default = 0,
	JunoUsage_Immutable = 1,
	JunoUsage_Dynamic = 2,
	JunoUsage_Staging = 3,
} JunoUsage;

typedef enum JunoBindFlags
{
	JunoBindFlags_None = 0,
	JunoBindFlags_VertexBuffer = 0x1,
	JunoBindFlags_IndexBuffer = 0x2,
	JunoBindFlags_ConstantBuffer = 0x4,
	JunoBindFlags_ShaderResource = 0x8,
	JunoBindFlags_StreamOutput = 0x10,
	JunoBindFlags_RenderTarget = 0x20,
	JunoBindFlags_DepthStencil = 0x40,
	JunoBindFlags_UnorderedAccess = 0x80,
} JunoBindFlags;

inline JunoBindFlags operator|(JunoBindFlags lhs, JunoBindFlags rhs) {
	using T = std::underlying_type_t<JunoBindFlags>;
	return static_cast<JunoBindFlags>(static_cast<T>(lhs) | static_cast<T>(rhs));
}

inline JunoBindFlags& operator|=(JunoBindFlags& lhs, JunoBindFlags rhs) {
	lhs = lhs | rhs;
	return lhs;
}

typedef enum JunoCpuAccessFlags
{
	JunoCpuAccessFlags_None = 0,
	JunoCpuAccessFlags_Write = 0x10000,
	JunoCpuAccessFlags_Read = 0x20000,
} JunoCpuAccessFlags;

typedef enum JunoMapMode
{
	JunoMapMode_Read = 1,
	JunoMapMode_Write = 2,
	JunoMapMode_ReadWrite = 3,
	JunoMapMode_WriteDiscard = 4,
	JunoMapMode_WriteNoOverwrite = 5,
} JunoMapMode;

typedef enum JunoClearFlags
{
	JunoClearFlags_Depth = 0x1,
	JunoClearFlags_Stencil = 0x2,
} JunoClearFlags;

typedef enum JunoShaderStage
{
	JunoShaderStage_Vertex = 0,
	JunoShaderStage_Pixel = 1,
	JunoShaderStage_Geometry = 2,
	JunoShaderStage_Compute = 3,
} JunoShaderStage;

typedef enum JunoShaderCompileFlags
{
	JunoShaderCompileFlags_None = 0,
	JunoShaderCompileFlags_Debug = 0x1,
	JunoShaderCompileFlags_SkipValidation = 0x2,
	JunoShaderCompileFlags_SkipOptimization = 0x4,
	JunoShaderCompileFlags_PackMatrixRowMajor = 0x8,
	JunoShaderCompileFlags_PackMatrixColumnMajor = 0x10,
	JunoShaderCompileFlags_EnableStrictness = 0x800,
	JunoShaderCompileFlags_OptimizationLevel0 = 0x4000,
	JunoShaderCompileFlags_OptimizationLevel3 = 0x8000,
	JunoShaderCompileFlags_WarningsAreErrors = 0x40000,
} JunoShaderCompileFlags;

typedef enum JunoPrimitiveTopology
{
	JunoPrimitiveTopology_PointList = 1,
	JunoPrimitiveTopology_LineList = 2,
	JunoPrimitiveTopology_LineStrip = 3,
	JunoPrimitiveTopology_TriangleList = 4,
	JunoPrimitiveTopology_TriangleStrip = 5,
} JunoPrimitiveTopology;

typedef enum JunoIndexFormat
{
	JunoIndexFormat_UInt16 = 0,
	JunoIndexFormat_UInt32 = 1,
} JunoIndexFormat;

typedef enum JunoInputClassification
{
	JunoInputClassification_PerVertexData = 0,
	JunoInputClassification_PerInstanceData = 1,
} JunoInputClassification;

typedef enum JunoBlendFactor
{
	JunoBlendFactor_Zero = 1,
	JunoBlendFactor_One = 2,
	JunoBlendFactor_SrcColor = 3,
	JunoBlendFactor_InvSrcColor = 4,
	JunoBlendFactor_SrcAlpha = 5,
	JunoBlendFactor_InvSrcAlpha = 6,
	JunoBlendFactor_DestAlpha = 7,
	JunoBlendFactor_InvDestAlpha = 8,
	JunoBlendFactor_DestColor = 9,
	JunoBlendFactor_InvDestColor = 10,
	JunoBlendFactor_SrcAlphaSat = 11,
	JunoBlendFactor_Constant = 14,
	JunoBlendFactor_InvConstant = 15,
} JunoBlendFactor;

typedef enum JunoBlendOp
{
	JunoBlendOp_Add = 1,
	JunoBlendOp_Subtract = 2,
	JunoBlendOp_RevSubtract = 3,
	JunoBlendOp_Min = 4,
	JunoBlendOp_Max = 5,
} JunoBlendOp;

typedef enum JunoColorWriteMask
{
	JunoColorWriteMask_Red = 1,
	JunoColorWriteMask_Green = 2,
	JunoColorWriteMask_Blue = 4,
	JunoColorWriteMask_Alpha = 8,
	JunoColorWriteMask_All = 15,
} JunoColorWriteMask;

typedef enum JunoComparisonFunc
{
	JunoComparisonFunc_Never = 1,
	JunoComparisonFunc_Less = 2,
	JunoComparisonFunc_Equal = 3,
	JunoComparisonFunc_LessEqual = 4,
	JunoComparisonFunc_Greater = 5,
	JunoComparisonFunc_NotEqual = 6,
	JunoComparisonFunc_GreaterEqual = 7,
	JunoComparisonFunc_Always = 8,
} JunoComparisonFunc;

typedef enum JunoStencilOp
{
	JunoStencilOp_Keep = 1,
	JunoStencilOp_Zero = 2,
	JunoStencilOp_Replace = 3,
	JunoStencilOp_IncrSat = 4,
	JunoStencilOp_DecrSat = 5,
	JunoStencilOp_Invert = 6,
	JunoStencilOp_Incr = 7,
	JunoStencilOp_Decr = 8,
} JunoStencilOp;

typedef enum JunoFillMode
{
	JunoFillMode_Wireframe = 2,
	JunoFillMode_Solid = 3,
} JunoFillMode;

typedef enum JunoCullMode
{
	JunoCullMode_None = 1,
	JunoCullMode_Front = 2,
	JunoCullMode_Back = 3,
} JunoCullMode;

typedef enum JunoFilter
{
	JunoFilter_MinMagMipPoint = 0x00,
	JunoFilter_MinMagPointMipLinear = 0x01,
	JunoFilter_MinPointMagLinearMipPoint = 0x04,
	JunoFilter_MinPointMagMipLinear = 0x05,
	JunoFilter_MinLinearMagMipPoint = 0x10,
	JunoFilter_MinLinearMagPointMipLinear = 0x11,
	JunoFilter_MinMagLinearMipPoint = 0x14,
	JunoFilter_MinMagMipLinear = 0x15,
	JunoFilter_Anisotropic = 0x55,
	JunoFilter_ComparisonMinMagMipPoint = 0x80,
	JunoFilter_ComparisonMinMagMipLinear = 0x95,
	JunoFilter_ComparisonAnisotropic = 0xD5,
} JunoFilter;

typedef enum JunoAddressMode
{
	JunoAddressMode_Wrap = 1,
	JunoAddressMode_Mirror = 2,
	JunoAddressMode_Clamp = 3,
	JunoAddressMode_Border = 4,
	JunoAddressMode_MirrorOnce = 5,
} JunoAddressMode;

/* ------------------------------------------------------------------------- */
/* Structs                                                                   */
/* ------------------------------------------------------------------------- */

typedef struct JunoDeviceCreateInfo
{
	c_bool bDebug;          /* Enable the D3D11 debug layer if it is installed. */
	c_bool bAllowWarp;      /* Fall back to the WARP software rasterizer. */
	c_int mAdapterIndex;    /* >= 0 picks an adapter by DXGI index, < 0 uses the default hardware adapter. */
} JunoDeviceCreateInfo;

typedef struct JunoShaderCreateInfo
{
	JunoDevice* mDevice;
	JunoShaderStage mStage;
	const void* mBytecode;
	c_size mBytecodeSize;
} JunoShaderCreateInfo;

typedef struct JunoShaderCompileFromFileInfo
{
	const c_wchar* mPath;
	const c_char* mEntryPoint;
	const c_char* mTarget;
	c_uint mCompileFlags;
} JunoShaderCompileFromFileInfo;

typedef struct JunoShaderCompileInfo
{
	const c_char* mSource;
	c_size mSourceLength;
	const c_char* mSourceName;
	const c_char* mEntryPoint;
	const c_char* mTarget;
	c_uint mCompileFlags;
} JunoShaderCompileInfo;

typedef struct JunoSwapChainCreateInfo
{
	JunoDevice* mDevice;
	void* mWindow;                  /* HWND. Required. */
	c_uint mWidth;                  /* 0 = use client area. */
	c_uint mHeight;                 /* 0 = use client area. */
	JunoPixelFormat mFormat;        /* Unknown = B8G8R8A8_UNorm. Flip model: B8G8R8A8/R8G8B8A8/R16G16B16A16_Float/R10G10B10A2. */
	JunoPixelFormat mDepthFormat;   /* Unknown = no depth buffer is created. */
	c_uint mBufferCount;            /* Clamped to >= 2. */
	c_bool bAllowTearing;           /* Use tearing when presenting without vsync (if supported). */
	c_bool bComposition;            /* DirectComposition swap chain with premultiplied alpha (transparent windows, Acrylic).
	                                   Create the window with WS_EX_NOREDIRECTIONBITMAP. */
} JunoSwapChainCreateInfo;

typedef struct JunoBufferCreateInfo
{
	JunoDevice* mDevice;
	c_size mSize;               /* Bytes. Constant buffers must be a multiple of 16. */
	c_uint mStride;             /* Required for structured buffers. */
	JunoUsage mUsage;
	c_uint mBindFlags;          /* JunoBindFlags */
	c_uint mCpuAccessFlags;     /* JunoCpuAccessFlags */
	c_bool bStructured;         /* Structured buffer. SRV/UAV are created according to mBindFlags. */
	void* mInitialData;         /* Initial data (optional, unless JunoUsage_Immutable is set) */
} JunoBufferCreateInfo;

typedef struct JunoTextureCreateInfo
{
	JunoDevice* mDevice;
	c_uint mWidth;
	c_uint mHeight;
	c_uint mMipLevels;                     /* 0 = full chain. */
	c_uint mArraySize;
	c_uint mSampleCount;
	JunoPixelFormat mFormat;
	JunoUsage mUsage;
	UINT mBindFlags;                       /* JunoBindFlags */
	UINT mCpuAccessFlags;                  /* JunoCpuAccessFlags */
	c_bool bGenerateMips;                  /* Adds RenderTarget + ShaderResource bind flags, generates mips after the initial upload. */
	c_bool bCubemap;                       /* mArraySize is forced to 6. */
	void* mInitialData;
	c_uint mRowPitch;
} JunoTextureCreateInfo;

typedef struct JunoRegion
{
	c_int mLeft;
	c_int mTop;
	c_int mRight;
	c_int mBottom;
} JunoRegion;

typedef struct JunoViewport
{
	float mTopLeftX;
	float mTopLeftY;
	float mWidth;
	float mHeight;
	float mMinDepth;
	float mMaxDepth;
} JunoViewport;

typedef struct JunoScissor
{
	c_int mLeft;
	c_int mTop;
	c_int mRight;
	c_int mBottom;
} JunoScissor;

typedef struct JunoSamplerCreateInfo
{
	JunoDevice* mDevice;
	JunoFilter mFilter;
	JunoAddressMode mAddressU;
	JunoAddressMode mAddressV;
	JunoAddressMode mAddressW;
	float mMipLODBias;
	c_uint mMaxAnisotropy;
	JunoComparisonFunc mComparisonFunc;
	float mBorderColorR;
	float mBorderColorG;
	float mBorderColorB;
	float mBorderColorA;
	float mMinLOD;
	float mMaxLOD;
} JunoSamplerCreateInfo;

typedef struct JunoInputElementDescription
{
	const c_char* mSemanticName;
	c_uint mSemanticIndex;
	JunoPixelFormat mFormat;
	c_uint mInputSlot;
	c_uint mAlignedByteOffset;      /* JUNO_APPEND_ALIGNED_ELEMENT to append after the previous element. */
	JunoInputClassification mInputSlotClass;
	c_uint mInstanceDataStepRate;
} JunoInputElementDescription;

typedef struct JunoBlendDesc
{
	c_bool bAlphaToCoverage;
	c_bool bBlendEnable;
	JunoBlendFactor mSrcBlend;
	JunoBlendFactor mDestBlend;
	JunoBlendOp mBlendOp;
	JunoBlendFactor mSrcBlendAlpha;
	JunoBlendFactor mDestBlendAlpha;
	JunoBlendOp mBlendOpAlpha;
	c_uchar mWriteMask;             /* JunoColorWriteMask. Applied to every render target. */
} JunoBlendDesc;

typedef struct JunoRasterizerDesc
{
	JunoFillMode mFillMode;
	JunoCullMode mCullMode;
	c_int mDepthBias;
	float mDepthBiasClamp;
	float mSlopeScaledDepthBias;
	c_bool bFrontCounterClockwise;
	c_bool bDepthClipEnable;
	c_bool bScissorEnable;
	c_bool bMultisampleEnable;
	c_bool bAntialiasedLineEnable;
} JunoRasterizerDesc;

typedef struct JunoStencilOpDesc
{
	JunoStencilOp mStencilFailOp;
	JunoStencilOp mStencilDepthFailOp;
	JunoStencilOp mStencilPassOp;
	JunoComparisonFunc mStencilFunc;
} JunoStencilOpDesc;

typedef struct JunoDepthStencilCreateInfo
{
	JunoDevice* mDevice;
	c_bool bDepthEnable;
	c_bool bDepthWriteEnable;
	JunoComparisonFunc mDepthFunc;
	c_bool bStencilEnable;
	c_uchar mStencilReadMask;
	c_uchar mStencilWriteMask;
	JunoStencilOpDesc mFrontFace;
	JunoStencilOpDesc mBackFace;
} JunoDepthStencilCreateInfo;

typedef struct JunoInteropLayoutSizes
{
	c_uint mJunoDeviceCreateInfo;
	c_uint mJunoShaderCreateInfo;
	c_uint mJunoShaderCompileFromFileInfo;
	c_uint mJunoShaderCompileInfo;
	c_uint mJunoSwapChainCreateInfo;
	c_uint mJunoBufferCreateInfo;
	c_uint mJunoTextureCreateInfo;
	c_uint mJunoRegion;
	c_uint mJunoViewport;
	c_uint mJunoScissor;
	c_uint mJunoSamplerCreateInfo;
	c_uint mJunoInputElementDescription;
	c_uint mJunoBlendDesc;
	c_uint mJunoRasterizerDesc;
	c_uint mJunoStencilOpDesc;
	c_uint mJunoDepthStencilCreateInfo;
	c_uint mJunoInteropLayoutSizes;
} JunoInteropLayoutSizes;

/* ------------------------------------------------------------------------- */
/* Error handling                                                            */
/* ------------------------------------------------------------------------- */

/* Per-thread. Message of the last failed call (for shader compilation it contains the compiler output). */
JUNO_API const c_char* JunoGetLastErrorMessage(void);
JUNO_API JunoErrorCode JunoGetLastErrorCode(void);
JUNO_API c_int JunoGetLastErrorHResult(void);
JUNO_API void JunoClearLastError(void);
JUNO_API void JunoGetInteropLayoutSizes(JunoInteropLayoutSizes* pSizes);

/* ------------------------------------------------------------------------- */
/* Device                                                                    */
/* ------------------------------------------------------------------------- */

JUNO_API JunoErrorCode JunoCreateDevice(const JunoDeviceCreateInfo* pDesc, JunoDevice** ppDevice);
JUNO_API void JunoDestroyDevice(JunoDevice* pDevice);
JUNO_API void JunoFlush(JunoDevice* pDevice);
JUNO_API void JunoClearState(JunoDevice* pDevice);

/* ------------------------------------------------------------------------- */
/* Swap chain                                                                */
/* ------------------------------------------------------------------------- */

JUNO_API JunoErrorCode JunoCreateSwapChain(const JunoSwapChainCreateInfo* pCreateInfo, JunoSwapChain** ppSwapChain);
JUNO_API void JunoDestroySwapChain(JunoSwapChain* pSwapChain);
JUNO_API JunoErrorCode JunoResizeSwapChain(JunoSwapChain* pSwapChain, c_uint width, c_uint height); /* 0,0 = client area */
JUNO_API JunoErrorCode JunoPresent(JunoSwapChain* pSwapChain, c_bool bVSync);
JUNO_API JunoTexture* JunoGetBackBuffer(JunoSwapChain* pSwapChain);     /* Owned by the swap chain. Do not destroy. */
JUNO_API JunoTexture* JunoGetDepthBuffer(JunoSwapChain* pSwapChain);    /* Owned by the swap chain. May be NULL. */

/* ------------------------------------------------------------------------- */
/* Buffers                                                                   */
/* ------------------------------------------------------------------------- */

JUNO_API JunoErrorCode JunoCreateBuffer(const JunoBufferCreateInfo* pCreateInfo, JunoBuffer** ppBuffer);
JUNO_API void JunoDestroyBuffer(JunoBuffer* pBuffer);
JUNO_API JunoErrorCode JunoUpdateBuffer(JunoDevice* pDevice, JunoBuffer* pBuffer, c_size offset, const void* pData, c_size size);
JUNO_API JunoErrorCode JunoMapBuffer(JunoDevice* pDevice, JunoBuffer* pBuffer, JunoMapMode mode, void** ppData);
JUNO_API void JunoUnmapBuffer(JunoDevice* pDevice, JunoBuffer* pBuffer);
JUNO_API void JunoCopyBuffer(JunoDevice* pDevice, JunoBuffer* pDst, JunoBuffer* pSrc);
JUNO_API void JunoSetVertexBuffers(JunoDevice* pDevice, c_uint startSlot, c_uint count, JunoBuffer* const* ppBuffers, const c_uint* pStrides, const c_uint* pOffsets);
JUNO_API void JunoSetIndexBuffer(JunoDevice* pDevice, JunoBuffer* pBuffer, JunoIndexFormat format, c_uint offset);
JUNO_API void JunoSetConstantBuffers(JunoDevice* pDevice, JunoShaderStage stage, c_uint startSlot, c_uint count, JunoBuffer* const* ppBuffers);
JUNO_API void JunoSetBufferResources(JunoDevice* pDevice, JunoShaderStage stage, c_uint startSlot, c_uint count, JunoBuffer* const* ppBuffers);
JUNO_API void JunoSetUnorderedAccessBuffers(JunoDevice* pDevice, c_uint startSlot, c_uint count, JunoBuffer* const* ppBuffers); /* compute stage */

/* ------------------------------------------------------------------------- */
/* Textures                                                                  */
/* ------------------------------------------------------------------------- */

JUNO_API JunoErrorCode JunoCreateTexture(const JunoTextureCreateInfo* pCreateInfo, JunoTexture** ppTexture);
JUNO_API void JunoDestroyTexture(JunoTexture* pTexture);
JUNO_API JunoErrorCode JunoUpdateTexture(JunoDevice* pDevice, JunoTexture* pTexture, c_uint arraySlice, c_uint mipLevel, const JunoRegion* pRegion, const void* pData, c_uint rowPitch);
JUNO_API JunoErrorCode JunoMapTexture(JunoDevice* pDevice, JunoTexture* pTexture, c_uint arraySlice, c_uint mipLevel, JunoMapMode mode, void** ppData, c_uint* pRowPitch);
JUNO_API void JunoUnmapTexture(JunoDevice* pDevice, JunoTexture* pTexture, c_uint arraySlice, c_uint mipLevel);
JUNO_API void JunoGenerateMips(JunoDevice* pDevice, JunoTexture* pTexture);
JUNO_API void JunoCopyTexture(JunoDevice* pDevice, JunoTexture* pDst, JunoTexture* pSrc);
JUNO_API void JunoResolveTexture(JunoDevice* pDevice, JunoTexture* pDst, JunoTexture* pSrc);
JUNO_API void JunoGetTextureSize(JunoTexture* pTexture, c_uint* pWidth, c_uint* pHeight);
JUNO_API void JunoClearRenderTarget(JunoDevice* pDevice, JunoTexture* pTexture, float r, float g, float b, float a);
JUNO_API void JunoClearDepthStencil(JunoDevice* pDevice, JunoTexture* pTexture, c_uint clearFlags, float depth, c_uchar stencil);
JUNO_API void JunoSetTextures(JunoDevice* pDevice, JunoShaderStage stage, c_uint startSlot, c_uint count, JunoTexture* const* ppTextures);
JUNO_API void JunoSetUnorderedAccessTextures(JunoDevice* pDevice, c_uint startSlot, c_uint count, JunoTexture* const* ppTextures); /* compute stage */

/* ------------------------------------------------------------------------- */
/* Images (CPU-side decoded pixels, PNG only)                                */
/* ------------------------------------------------------------------------- */

/*
 * Decodes a PNG from memory (the caller keeps ownership of pData; it is not referenced after the call).
 * mDesiredFormat selects the pixel layout the image is converted to while loading:
 *   JunoPixelFormat_Unknown             Keep the source layout: 1 channel -> R8_UNorm, 2 -> R8G8_UNorm,
 *                                       3 or 4 -> R8G8B8A8_UNorm (D3D11 has no 3-channel 8-bit format; alpha = 255).
 *   JunoPixelFormat_R8_UNorm            1 channel. Colour sources are converted to luminance.
 *   JunoPixelFormat_R8G8_UNorm          2 channels (grey + alpha).
 *   JunoPixelFormat_R8G8B8A8_UNorm      4 channels. Grey sources are replicated into RGB, missing alpha = 255.
 *   JunoPixelFormat_R8G8B8A8_UNorm_SRGB Same pixels as above, but the image is tagged sRGB so that the
 *                                       texture created from it is sampled with sRGB -> linear conversion.
 * Any other value fails with JunoErrorCode_Unsupported. 16-bit PNGs are reduced to 8 bits per channel.
 */
JUNO_API JunoErrorCode JunoLoadImage(const void* pData, c_size size, JunoPixelFormat desiredFormat, JunoImage** ppImage);
JUNO_API void JunoDestroyImage(JunoImage* pImage);

/* Convenience: creates an immutable-sized, shader-readable texture from the image (Default usage, ShaderResource bind). */
JUNO_API JunoErrorCode JunoCreateTextureFromImage(JunoDevice* pDevice, JunoImage* pImage, c_bool bGenerateMips, JunoTexture** ppTexture);

/* ------------------------------------------------------------------------- */
/* Samplers                                                                  */
/* ------------------------------------------------------------------------- */

JUNO_API JunoErrorCode JunoCreateSampler(const JunoSamplerCreateInfo* pCreateInfo, JunoSampler** ppSampler);
JUNO_API void JunoDestroySampler(JunoSampler* pSampler);
JUNO_API void JunoSetSamplers(JunoDevice* pDevice, JunoShaderStage stage, c_uint startSlot, c_uint count, JunoSampler* const* ppSamplers);

/* ------------------------------------------------------------------------- */
/* Shaders                                                                   */
/* ------------------------------------------------------------------------- */

JUNO_API JunoErrorCode JunoCompileShader(const JunoShaderCompileInfo* pCompileInfo, JunoBlob** ppBlob);
JUNO_API JunoErrorCode JunoCompileShaderFromFile(const JunoShaderCompileFromFileInfo* pCompileInfo, JunoBlob** ppBlob);
JUNO_API const void* JunoGetBlobData(JunoBlob* pBlob);
JUNO_API c_size JunoGetBlobSize(JunoBlob* pBlob);
JUNO_API void JunoDestroyBlob(JunoBlob* pBlob);
JUNO_API JunoErrorCode JunoCreateShader(JunoShaderCreateInfo* pCreateInfo, JunoShader** ppShader);
JUNO_API void JunoDestroyShader(JunoShader* pShader);
JUNO_API void JunoSetShader(JunoDevice* pDevice, JunoShader* pShader);
JUNO_API void JunoUnsetShader(JunoDevice* pDevice, JunoShaderStage stage);

/* ------------------------------------------------------------------------- */
/* Input layout                                                              */
/* ------------------------------------------------------------------------- */

JUNO_API JunoErrorCode JunoCreateInputLayout(JunoDevice* pDevice, const JunoInputElementDescription* pElements, c_uint elementCount, const void* pVertexShaderBytecode, c_size vertexShaderBytecodeSize, JunoInputLayout** ppLayout);
JUNO_API void JunoDestroyInputLayout(JunoInputLayout* pLayout);
JUNO_API void JunoSetInputLayout(JunoDevice* pDevice, JunoInputLayout* pLayout);

/* ------------------------------------------------------------------------- */
/* Render states                                                             */
/* ------------------------------------------------------------------------- */

JUNO_API JunoErrorCode JunoCreateBlendState(JunoDevice* pDevice, const JunoBlendDesc* pDesc, JunoBlendState** ppState);
JUNO_API void JunoDestroyBlendState(JunoBlendState* pState);
JUNO_API void JunoSetBlendState(JunoDevice* pDevice, JunoBlendState* pState, const float* pBlendFactor, c_uint sampleMask); /* pBlendFactor NULL = {1,1,1,1} */

JUNO_API JunoErrorCode JunoCreateRasterizerState(JunoDevice* pDevice, const JunoRasterizerDesc* pDesc, JunoRasterizerState** ppState);
JUNO_API void JunoDestroyRasterizerState(JunoRasterizerState* pState);
JUNO_API void JunoSetRasterizerState(JunoDevice* pDevice, JunoRasterizerState* pState);

JUNO_API JunoErrorCode JunoCreateDepthStencilState(const JunoDepthStencilCreateInfo* pCreateInfo, JunoDepthStencilState** ppState);
JUNO_API void JunoDestroyDepthStencilState(JunoDepthStencilState* pState);
JUNO_API void JunoSetDepthStencilState(JunoDevice* pDevice, JunoDepthStencilState* pState, c_uint stencilRef);

/* ------------------------------------------------------------------------- */
/* Pipeline / drawing                                                        */
/* ------------------------------------------------------------------------- */

JUNO_API void JunoSetRenderTargets(JunoDevice* pDevice, c_uint count, JunoTexture* const* ppColorTargets, JunoTexture* pDepthTarget);
JUNO_API void JunoSetViewports(JunoDevice* pDevice, c_uint count, const JunoViewport* pViewports);
JUNO_API void JunoSetScissorRects(JunoDevice* pDevice, const JunoScissor* pScissors, c_uint count);
JUNO_API void JunoSetPrimitiveTopology(JunoDevice* pDevice, JunoPrimitiveTopology topology);

JUNO_API void JunoDraw(JunoDevice* pDevice, c_uint vertexCount, c_uint startVertex);
JUNO_API void JunoDrawIndexed(JunoDevice* pDevice, c_uint indexCount, c_uint startIndex, c_int baseVertex);
JUNO_API void JunoDrawInstanced(JunoDevice* pDevice, c_uint vertexCountPerInstance, c_uint instanceCount, c_uint startVertex, c_uint startInstance);
JUNO_API void JunoDrawIndexedInstanced(JunoDevice* pDevice, c_uint indexCountPerInstance, c_uint instanceCount, c_uint startIndex, c_int baseVertex, c_uint startInstance);
JUNO_API void JunoDispatch(JunoDevice* pDevice, c_uint groupsX, c_uint groupsY, c_uint groupsZ);

/* ------------------------------------------------------------------------- */
/* Fence (GPU event query)                                                   */
/* ------------------------------------------------------------------------- */

JUNO_API JunoErrorCode JunoCreateFence(JunoDevice* pDevice, JunoFence** ppFence);
JUNO_API void JunoDestroyFence(JunoFence* pFence);
JUNO_API void JunoInsertFence(JunoDevice* pDevice, JunoFence* pFence);
JUNO_API c_bool JunoIsFenceSignaled(JunoDevice* pDevice, JunoFence* pFence);
JUNO_API void JunoWaitFence(JunoDevice* pDevice, JunoFence* pFence);
