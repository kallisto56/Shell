#include "pch.h"
#include "JunoInternal.h"

struct FormatSet
{
	DXGI_FORMAT mResource;
	DXGI_FORMAT mSrv;
	DXGI_FORMAT mDsv;
};

// Depth textures that are also sampled need a typeless resource format and typed views.
static FormatSet ResolveFormats(DXGI_FORMAT format, bool bDepth, bool bSrv)
{
	FormatSet set = { format, format, format };
	if (bDepth && bSrv)
	{
		switch (format)
		{
		case DXGI_FORMAT_D32_FLOAT:
			set.mResource = DXGI_FORMAT_R32_TYPELESS;
			set.mSrv = DXGI_FORMAT_R32_FLOAT;
			break;
		case DXGI_FORMAT_D24_UNORM_S8_UINT:
			set.mResource = DXGI_FORMAT_R24G8_TYPELESS;
			set.mSrv = DXGI_FORMAT_R24_UNORM_X8_TYPELESS;
			break;
		case DXGI_FORMAT_D16_UNORM:
			set.mResource = DXGI_FORMAT_R16_TYPELESS;
			set.mSrv = DXGI_FORMAT_R16_UNORM;
			break;
		default:
			break;
		}
	}
	return set;
}

JUNO_API JunoErrorCode JunoCreateTexture(const JunoTextureCreateInfo* pCreateInfo, JunoTexture** ppTexture)
{
	JUNO_ASSERT(pCreateInfo->mDevice != nullptr);
	JUNO_ASSERT(pCreateInfo != nullptr);
	JUNO_ASSERT(ppTexture != nullptr);
	*ppTexture = nullptr;
	JUNO_ASSERT(pCreateInfo->mWidth > 0 && pCreateInfo->mHeight > 0);
	JUNO_ASSERT(pCreateInfo->mFormat != JunoPixelFormat_Unknown);
	JUNO_ASSERT(pCreateInfo->mInitialData == nullptr || pCreateInfo->mRowPitch > 0);

	JunoTextureCreateInfo desc = *pCreateInfo;
	if (desc.mSampleCount == 0)
		desc.mSampleCount = 1;
	if (desc.bCubemap)
		desc.mArraySize = 6;
	else if (desc.mArraySize == 0)
		desc.mArraySize = 1;
	if (desc.mSampleCount > 1)
		desc.mMipLevels = 1;

	UINT bind = desc.mBindFlags;
	UINT misc = 0;
	if (desc.bGenerateMips)
	{
		JUNO_ASSERT(desc.mUsage == JunoUsage_Default);
		JUNO_ASSERT(desc.mSampleCount == 1);
		bind |= D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
		misc |= D3D11_RESOURCE_MISC_GENERATE_MIPS;
	}
	if (desc.bCubemap)
		misc |= D3D11_RESOURCE_MISC_TEXTURECUBE;

	// Immutable textures must supply their data at creation: only a single mip / slice is supported there.
	const bool bImmutable = (desc.mUsage == JunoUsage_Immutable);
	if (bImmutable)
	{
		JUNO_ASSERT(pCreateInfo->mInitialData != nullptr);
		JUNO_ASSERT(desc.mMipLevels == 1 && desc.mArraySize == 1);
	}

	const bool bDepth = (bind & D3D11_BIND_DEPTH_STENCIL) != 0;
	const bool bSrv = (bind & D3D11_BIND_SHADER_RESOURCE) != 0;
	const FormatSet formats = ResolveFormats((DXGI_FORMAT)desc.mFormat, bDepth, bSrv);

	D3D11_TEXTURE2D_DESC td = {};
	td.Width = desc.mWidth;
	td.Height = desc.mHeight;
	td.MipLevels = desc.mMipLevels;
	td.ArraySize = desc.mArraySize;
	td.Format = formats.mResource;
	td.SampleDesc.Count = desc.mSampleCount;
	td.SampleDesc.Quality = 0;
	td.Usage = (D3D11_USAGE)desc.mUsage;
	td.BindFlags = bind;
	td.CPUAccessFlags = desc.mCpuAccessFlags;
	td.MiscFlags = misc;

	D3D11_SUBRESOURCE_DATA init = {};
	init.pSysMem = pCreateInfo->mInitialData;
	init.SysMemPitch = pCreateInfo->mRowPitch;

	JunoTexture* pTexture = new (std::nothrow) JunoTexture();
	JUNO_REQUIRE_ALLOC(pTexture);

	ID3D11Device* pNative = pCreateInfo->mDevice->mDevice.Get();
	ID3D11DeviceContext* pCtx = pCreateInfo->mDevice->mContext.Get();

	HRESULT hr = pNative->CreateTexture2D(&td, bImmutable ? &init : nullptr, &pTexture->mTexture);
	if (FAILED(hr))
	{
		delete pTexture;
		return JunoFailHResult(JunoErrorCode_TextureCreationFailed, hr, "ID3D11Device::CreateTexture2D");
	}

	// Read back what D3D actually created (mip count for 0 = full chain).
	pTexture->mTexture->GetDesc(&td);
	desc.mMipLevels = td.MipLevels;
	desc.mBindFlags = bind;
	pTexture->mCreateInfo = desc;

	ID3D11Texture2D* pRes = pTexture->mTexture.Get();

	if (bind & D3D11_BIND_SHADER_RESOURCE)
	{
		D3D11_SHADER_RESOURCE_VIEW_DESC sv = {};
		sv.Format = formats.mSrv;
		if (desc.bCubemap)
		{
			sv.ViewDimension = D3D11_SRV_DIMENSION_TEXTURECUBE;
			sv.TextureCube.MostDetailedMip = 0;
			sv.TextureCube.MipLevels = (UINT)-1;
		}
		else if (desc.mSampleCount > 1)
		{
			sv.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2DMS;
		}
		else if (desc.mArraySize > 1)
		{
			sv.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2DARRAY;
			sv.Texture2DArray.MostDetailedMip = 0;
			sv.Texture2DArray.MipLevels = (UINT)-1;
			sv.Texture2DArray.FirstArraySlice = 0;
			sv.Texture2DArray.ArraySize = desc.mArraySize;
		}
		else
		{
			sv.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
			sv.Texture2D.MostDetailedMip = 0;
			sv.Texture2D.MipLevels = (UINT)-1;
		}
		hr = pNative->CreateShaderResourceView(pRes, &sv, &pTexture->mSRV);
		if (FAILED(hr))
		{
			delete pTexture;
			return JunoFailHResult(JunoErrorCode_TextureCreationFailed, hr, "CreateShaderResourceView (texture)");
		}
	}

	if (bind & D3D11_BIND_RENDER_TARGET)
	{
		hr = pNative->CreateRenderTargetView(pRes, nullptr, &pTexture->mRTV);
		if (FAILED(hr))
		{
			delete pTexture;
			return JunoFailHResult(JunoErrorCode_TextureCreationFailed, hr, "CreateRenderTargetView (texture)");
		}
	}

	if (bind & D3D11_BIND_DEPTH_STENCIL)
	{
		D3D11_DEPTH_STENCIL_VIEW_DESC dv = {};
		dv.Format = formats.mDsv;
		if (desc.mSampleCount > 1)
		{
			dv.ViewDimension = D3D11_DSV_DIMENSION_TEXTURE2DMS;
		}
		else if (desc.mArraySize > 1)
		{
			dv.ViewDimension = D3D11_DSV_DIMENSION_TEXTURE2DARRAY;
			dv.Texture2DArray.MipSlice = 0;
			dv.Texture2DArray.FirstArraySlice = 0;
			dv.Texture2DArray.ArraySize = desc.mArraySize;
		}
		else
		{
			dv.ViewDimension = D3D11_DSV_DIMENSION_TEXTURE2D;
			dv.Texture2D.MipSlice = 0;
		}
		hr = pNative->CreateDepthStencilView(pRes, &dv, &pTexture->mDSV);
		if (FAILED(hr))
		{
			delete pTexture;
			return JunoFailHResult(JunoErrorCode_TextureCreationFailed, hr, "CreateDepthStencilView (texture)");
		}
	}

	if (bind & D3D11_BIND_UNORDERED_ACCESS)
	{
		D3D11_UNORDERED_ACCESS_VIEW_DESC uv = {};
		uv.Format = formats.mDsv;
		if (desc.mArraySize > 1)
		{
			uv.ViewDimension = D3D11_UAV_DIMENSION_TEXTURE2DARRAY;
			uv.Texture2DArray.MipSlice = 0;
			uv.Texture2DArray.FirstArraySlice = 0;
			uv.Texture2DArray.ArraySize = desc.mArraySize;
		}
		else
		{
			uv.ViewDimension = D3D11_UAV_DIMENSION_TEXTURE2D;
			uv.Texture2D.MipSlice = 0;
		}
		hr = pNative->CreateUnorderedAccessView(pRes, &uv, &pTexture->mUAV);
		if (FAILED(hr))
		{
			delete pTexture;
			return JunoFailHResult(JunoErrorCode_TextureCreationFailed, hr, "CreateUnorderedAccessView (texture)");
		}
	}

	if (pCreateInfo->mInitialData != nullptr && !bImmutable)
	{
		pCtx->UpdateSubresource(pRes, 0, nullptr, pCreateInfo->mInitialData, pCreateInfo->mRowPitch, 0);
		if (desc.bGenerateMips)
			pCtx->GenerateMips(pTexture->mSRV.Get());
	}

	*ppTexture = pTexture;
	return JunoErrorCode_Ok;
}

JUNO_API JunoErrorCode JunoCreateTextureFromImage(JunoDevice* pDevice, JunoImage* pImage, c_bool bGenerateMips, JunoTexture** ppTexture)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(pImage != nullptr);
	JUNO_ASSERT(ppTexture != nullptr);

	JunoTextureCreateInfo createInfo = {};
	createInfo.mDevice = pDevice;
	createInfo.mWidth = pImage->mWidth;
	createInfo.mHeight = pImage->mHeight;
	createInfo.mMipLevels = bGenerateMips ? 0 : 1;    // 0 = full chain, generated after the upload
	createInfo.mArraySize = 1;
	createInfo.mSampleCount = 1;
	createInfo.mFormat = pImage->mFormat;
	createInfo.mUsage = JunoUsage_Default;
	createInfo.mBindFlags = JunoBindFlags_ShaderResource;
	createInfo.mCpuAccessFlags = JunoCpuAccessFlags_None;
	createInfo.bGenerateMips = bGenerateMips;
	createInfo.bCubemap = false;
	createInfo.mInitialData = pImage->mPixels;
	createInfo.mRowPitch = pImage->mRowPitch;

	return JunoCreateTexture(&createInfo, ppTexture);
}

JUNO_API void JunoDestroyTexture(JunoTexture* pTexture)
{
	if (pTexture == nullptr)
		return;
	assert(!pTexture->bOwnedBySwapChain && "Textures returned by JunoGetBackBuffer/JunoGetDepthBuffer are owned by the swap chain");
	if (pTexture->bOwnedBySwapChain)
		return;
	delete pTexture;
}

JUNO_API JunoErrorCode JunoUpdateTexture(JunoDevice* pDevice, JunoTexture* pTexture, c_uint arraySlice, c_uint mipLevel, const JunoRegion* pRegion, const void* pData, c_uint rowPitch)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(pTexture != nullptr);
	JUNO_ASSERT(pData != nullptr);
	JUNO_ASSERT(rowPitch > 0);
	JUNO_ASSERT(pTexture->mCreateInfo.mUsage == JunoUsage_Default);
	JUNO_ASSERT(arraySlice < pTexture->mCreateInfo.mArraySize);
	JUNO_ASSERT(mipLevel < pTexture->mCreateInfo.mMipLevels);

	UINT subresource = D3D11CalcSubresource(mipLevel, arraySlice, pTexture->mCreateInfo.mMipLevels);

	D3D11_BOX box = {};
	const D3D11_BOX* pBox = nullptr;
	if (pRegion != nullptr)
	{
		box.left = (UINT)pRegion->mLeft;
		box.top = (UINT)pRegion->mTop;
		box.right = (UINT)pRegion->mRight;
		box.bottom = (UINT)pRegion->mBottom;
		box.front = 0;
		box.back = 1;
		pBox = &box;
	}

	pDevice->mContext->UpdateSubresource(pTexture->mTexture.Get(), subresource, pBox, pData, rowPitch, 0);
	return JunoErrorCode_Ok;
}

JUNO_API JunoErrorCode JunoMapTexture(JunoDevice* pDevice, JunoTexture* pTexture, c_uint arraySlice, c_uint mipLevel, JunoMapMode mode, void** ppData, c_uint* pRowPitch)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(pTexture != nullptr);
	JUNO_ASSERT(ppData != nullptr);
	JUNO_ASSERT(pRowPitch != nullptr);
	*ppData = nullptr;
	*pRowPitch = 0;

	UINT subresource = D3D11CalcSubresource(mipLevel, arraySlice, pTexture->mCreateInfo.mMipLevels);
	D3D11_MAPPED_SUBRESOURCE mapped = {};
	HRESULT hr = pDevice->mContext->Map(pTexture->mTexture.Get(), subresource, (D3D11_MAP)mode, 0, &mapped);
	if (FAILED(hr))
		return JunoFailHResult(JunoErrorCode_MapFailed, hr, "ID3D11DeviceContext::Map (texture)");

	*ppData = mapped.pData;
	*pRowPitch = mapped.RowPitch;
	return JunoErrorCode_Ok;
}

JUNO_API void JunoUnmapTexture(JunoDevice* pDevice, JunoTexture* pTexture, c_uint arraySlice, c_uint mipLevel)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(pTexture != nullptr);
	UINT subresource = D3D11CalcSubresource(mipLevel, arraySlice, pTexture->mCreateInfo.mMipLevels);
	pDevice->mContext->Unmap(pTexture->mTexture.Get(), subresource);
}

JUNO_API void JunoGenerateMips(JunoDevice* pDevice, JunoTexture* pTexture)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(pTexture != nullptr);
	JUNO_ASSERT(pTexture->mSRV != nullptr); // Needs bGenerateMips at creation.
	pDevice->mContext->GenerateMips(pTexture->mSRV.Get());
}

JUNO_API void JunoCopyTexture(JunoDevice* pDevice, JunoTexture* pDst, JunoTexture* pSrc)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(pDst != nullptr);
	JUNO_ASSERT(pSrc != nullptr);
	pDevice->mContext->CopyResource(pDst->mTexture.Get(), pSrc->mTexture.Get());
}

JUNO_API void JunoResolveTexture(JunoDevice* pDevice, JunoTexture* pDst, JunoTexture* pSrc)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(pDst != nullptr);
	JUNO_ASSERT(pSrc != nullptr);
	pDevice->mContext->ResolveSubresource(pDst->mTexture.Get(), 0, pSrc->mTexture.Get(), 0, (DXGI_FORMAT)pDst->mCreateInfo.mFormat);
}

JUNO_API void JunoGetTextureSize(JunoTexture* pTexture, c_uint* pWidth, c_uint* pHeight)
{
	JUNO_ASSERT(pTexture != nullptr);
	if (pWidth) *pWidth = pTexture->mCreateInfo.mWidth;
	if (pHeight) *pHeight = pTexture->mCreateInfo.mHeight;
}

JUNO_API void JunoClearRenderTarget(JunoDevice* pDevice, JunoTexture* pTexture, float r, float g, float b, float a)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(pTexture != nullptr);
	JUNO_ASSERT(pTexture->mRTV != nullptr);
	const float color[4] = { r, g, b, a };
	pDevice->mContext->ClearRenderTargetView(pTexture->mRTV.Get(), color);
}

JUNO_API void JunoClearDepthStencil(JunoDevice* pDevice, JunoTexture* pTexture, c_uint clearFlags, float depth, c_uchar stencil)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(pTexture != nullptr);
	JUNO_ASSERT(pTexture->mDSV != nullptr);
	pDevice->mContext->ClearDepthStencilView(pTexture->mDSV.Get(), clearFlags, depth, stencil);
}

JUNO_API void JunoSetTextures(JunoDevice* pDevice, JunoShaderStage stage, c_uint startSlot, c_uint count, JunoTexture* const* ppTextures)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(startSlot + count <= JUNO_MAX_SRV_SLOTS);
	JUNO_ASSERT(count == 0 || ppTextures != nullptr);

	ID3D11ShaderResourceView* views[JUNO_MAX_SRV_SLOTS] = {};
	for (c_uint i = 0; i < count; ++i)
		views[i] = ppTextures[i] ? ppTextures[i]->mSRV.Get() : nullptr;

	JunoBindShaderResources(pDevice->mContext.Get(), stage, startSlot, count, views);
}

JUNO_API void JunoSetUnorderedAccessTextures(JunoDevice* pDevice, c_uint startSlot, c_uint count, JunoTexture* const* ppTextures)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(startSlot + count <= JUNO_MAX_UAV_SLOTS);
	JUNO_ASSERT(count == 0 || ppTextures != nullptr);

	ID3D11UnorderedAccessView* views[JUNO_MAX_UAV_SLOTS] = {};
	for (c_uint i = 0; i < count; ++i)
		views[i] = ppTextures[i] ? ppTextures[i]->mUAV.Get() : nullptr;

	pDevice->mContext->CSSetUnorderedAccessViews(startSlot, count, views, nullptr);
}
