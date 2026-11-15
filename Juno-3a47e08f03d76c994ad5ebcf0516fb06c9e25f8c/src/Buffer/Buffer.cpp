#include "pch.h"
#include "JunoInternal.h"

JUNO_API JunoErrorCode JunoCreateBuffer(const JunoBufferCreateInfo* pCreateInfo, JunoBuffer** ppBuffer)
{
	JUNO_ASSERT(pCreateInfo != nullptr);
	JUNO_ASSERT(pCreateInfo->mDevice != nullptr);
	JUNO_ASSERT(ppBuffer != nullptr);
	*ppBuffer = nullptr;
	JUNO_ASSERT(pCreateInfo->mSize > 0);
	JUNO_ASSERT(pCreateInfo->mUsage != JunoUsage_Immutable || pCreateInfo->mInitialData != nullptr);
	JUNO_ASSERT((pCreateInfo->mBindFlags & JunoBindFlags_ConstantBuffer) == 0 || (pCreateInfo->mSize % 16) == 0);
	JUNO_ASSERT(!pCreateInfo->bStructured || pCreateInfo->mStride > 0);

	D3D11_BUFFER_DESC bd = {};
	bd.ByteWidth = pCreateInfo->mSize;
	bd.Usage = (D3D11_USAGE)pCreateInfo->mUsage;
	bd.BindFlags = pCreateInfo->mBindFlags;
	bd.CPUAccessFlags = pCreateInfo->mCpuAccessFlags;
	bd.StructureByteStride = pCreateInfo->mStride;
	if (pCreateInfo->bStructured)
		bd.MiscFlags = D3D11_RESOURCE_MISC_BUFFER_STRUCTURED;

	D3D11_SUBRESOURCE_DATA init = {};
	init.pSysMem = pCreateInfo->mInitialData;

	JunoBuffer* pBuffer = new (std::nothrow) JunoBuffer();
	JUNO_REQUIRE_ALLOC(pBuffer);
	pBuffer->mCreateInfo = *pCreateInfo;

	ID3D11Device* pNative = pCreateInfo->mDevice->mDevice.Get();
	HRESULT hr = pNative->CreateBuffer(&bd, pCreateInfo->mInitialData ? &init : nullptr, &pBuffer->mHandle);
	if (FAILED(hr))
	{
		delete pBuffer;
		return JunoFailHResult(JunoErrorCode_BufferCreationFailed, hr, "ID3D11Device::CreateBuffer");
	}

	if (pCreateInfo->bStructured && (pCreateInfo->mBindFlags & JunoBindFlags_ShaderResource))
	{
		D3D11_SHADER_RESOURCE_VIEW_DESC sv = {};
		sv.Format = DXGI_FORMAT_UNKNOWN;
		sv.ViewDimension = D3D11_SRV_DIMENSION_BUFFER;
		sv.Buffer.FirstElement = 0;
		sv.Buffer.NumElements = pCreateInfo->mSize / pCreateInfo->mStride;
		hr = pNative->CreateShaderResourceView(pBuffer->mHandle.Get(), &sv, &pBuffer->mSRV);
		if (FAILED(hr))
		{
			delete pBuffer;
			return JunoFailHResult(JunoErrorCode_BufferCreationFailed, hr, "CreateShaderResourceView (buffer)");
		}
	}

	if (pCreateInfo->bStructured && (pCreateInfo->mBindFlags & JunoBindFlags_UnorderedAccess))
	{
		D3D11_UNORDERED_ACCESS_VIEW_DESC uv = {};
		uv.Format = DXGI_FORMAT_UNKNOWN;
		uv.ViewDimension = D3D11_UAV_DIMENSION_BUFFER;
		uv.Buffer.FirstElement = 0;
		uv.Buffer.NumElements = pCreateInfo->mSize / pCreateInfo->mStride;
		hr = pNative->CreateUnorderedAccessView(pBuffer->mHandle.Get(), &uv, &pBuffer->mUAV);
		if (FAILED(hr))
		{
			delete pBuffer;
			return JunoFailHResult(JunoErrorCode_BufferCreationFailed, hr, "CreateUnorderedAccessView (buffer)");
		}
	}

	*ppBuffer = pBuffer;
	return JunoErrorCode_Ok;
}

JUNO_API void JunoDestroyBuffer(JunoBuffer* pBuffer)
{
	delete pBuffer;
}

JUNO_API JunoErrorCode JunoUpdateBuffer(JunoDevice* pDevice, JunoBuffer* pBuffer, c_size offset, const void* pData, c_size size)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(pBuffer != nullptr);
	JUNO_ASSERT(pData != nullptr);
	JUNO_ASSERT(size > 0 && offset + size <= pBuffer->mCreateInfo.mSize);

	const JunoUsage usage = pBuffer->mCreateInfo.mUsage;
	JUNO_ASSERT(usage != JunoUsage_Immutable);

	ID3D11DeviceContext* pCtx = pDevice->mContext.Get();
	ID3D11Buffer* pNative = pBuffer->mHandle.Get();

	if (usage == JunoUsage_Dynamic || usage == JunoUsage_Staging)
	{
		// Dynamic: offset 0 discards the old contents, other offsets append (vertex/index buffers only).
		D3D11_MAP mapType = (usage == JunoUsage_Staging) ? D3D11_MAP_WRITE : (offset == 0 ? D3D11_MAP_WRITE_DISCARD : D3D11_MAP_WRITE_NO_OVERWRITE);
		D3D11_MAPPED_SUBRESOURCE mapped = {};
		HRESULT hr = pCtx->Map(pNative, 0, mapType, 0, &mapped);
		if (FAILED(hr))
			return JunoFailHResult(JunoErrorCode_MapFailed, hr, "ID3D11DeviceContext::Map");
		memcpy((unsigned char*)mapped.pData + offset, pData, size);
		pCtx->Unmap(pNative, 0);
		return JunoErrorCode_Ok;
	}

	const bool bWhole = (offset == 0 && size == pBuffer->mCreateInfo.mSize);
	const bool bConstant = (pBuffer->mCreateInfo.mBindFlags & JunoBindFlags_ConstantBuffer) != 0;
	JUNO_ASSERT(!bConstant || bWhole); // Partial updates of constant buffers are not allowed.

	if (bWhole)
	{
		pCtx->UpdateSubresource(pNative, 0, nullptr, pData, 0, 0);
	}
	else
	{
		D3D11_BOX box = { offset, 0, 0, offset + size, 1, 1 };
		pCtx->UpdateSubresource(pNative, 0, &box, pData, 0, 0);
	}
	return JunoErrorCode_Ok;
}

JUNO_API JunoErrorCode JunoMapBuffer(JunoDevice* pDevice, JunoBuffer* pBuffer, JunoMapMode mode, void** ppData)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(pBuffer != nullptr);
	JUNO_ASSERT(ppData != nullptr);
	*ppData = nullptr;

	D3D11_MAPPED_SUBRESOURCE mapped = {};
	HRESULT hr = pDevice->mContext->Map(pBuffer->mHandle.Get(), 0, (D3D11_MAP)mode, 0, &mapped);
	if (FAILED(hr))
		return JunoFailHResult(JunoErrorCode_MapFailed, hr, "ID3D11DeviceContext::Map");

	*ppData = mapped.pData;
	return JunoErrorCode_Ok;
}

JUNO_API void JunoUnmapBuffer(JunoDevice* pDevice, JunoBuffer* pBuffer)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(pBuffer != nullptr);
	pDevice->mContext->Unmap(pBuffer->mHandle.Get(), 0);
}

JUNO_API void JunoCopyBuffer(JunoDevice* pDevice, JunoBuffer* pDst, JunoBuffer* pSrc)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(pDst != nullptr);
	JUNO_ASSERT(pSrc != nullptr);
	pDevice->mContext->CopyResource(pDst->mHandle.Get(), pSrc->mHandle.Get());
}

JUNO_API void JunoSetVertexBuffers(JunoDevice* pDevice, c_uint startSlot, c_uint count, JunoBuffer* const* ppBuffers, const c_uint* pStrides, const c_uint* pOffsets)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(count <= JUNO_MAX_VB_SLOTS);
	JUNO_ASSERT(count == 0 || ppBuffers != nullptr);
	JUNO_ASSERT(count == 0 || pStrides != nullptr);

	ID3D11Buffer* buffers[JUNO_MAX_VB_SLOTS] = {};
	UINT zeroOffsets[JUNO_MAX_VB_SLOTS] = {};
	for (c_uint i = 0; i < count; ++i)
		buffers[i] = ppBuffers[i] ? ppBuffers[i]->mHandle.Get() : nullptr;

	pDevice->mContext->IASetVertexBuffers(startSlot, count, buffers, pStrides, pOffsets ? pOffsets : zeroOffsets);
}

JUNO_API void JunoSetIndexBuffer(JunoDevice* pDevice, JunoBuffer* pBuffer, JunoIndexFormat format, c_uint offset)
{
	JUNO_ASSERT(pDevice != nullptr);
	DXGI_FORMAT dxgiFormat = (format == JunoIndexFormat_UInt16) ? DXGI_FORMAT_R16_UINT : DXGI_FORMAT_R32_UINT;
	pDevice->mContext->IASetIndexBuffer(pBuffer ? pBuffer->mHandle.Get() : nullptr, dxgiFormat, offset);
}

JUNO_API void JunoSetConstantBuffers(JunoDevice* pDevice, JunoShaderStage stage, c_uint startSlot, c_uint count, JunoBuffer* const* ppBuffers)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(startSlot + count <= JUNO_MAX_CB_SLOTS);
	JUNO_ASSERT(count == 0 || ppBuffers != nullptr);

	ID3D11Buffer* buffers[JUNO_MAX_CB_SLOTS] = {};
	for (c_uint i = 0; i < count; ++i)
		buffers[i] = ppBuffers[i] ? ppBuffers[i]->mHandle.Get() : nullptr;

	JunoBindConstantBuffers(pDevice->mContext.Get(), stage, startSlot, count, buffers);
}

JUNO_API void JunoSetBufferResources(JunoDevice* pDevice, JunoShaderStage stage, c_uint startSlot, c_uint count, JunoBuffer* const* ppBuffers)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(startSlot + count <= JUNO_MAX_SRV_SLOTS);
	JUNO_ASSERT(count == 0 || ppBuffers != nullptr);

	ID3D11ShaderResourceView* views[JUNO_MAX_SRV_SLOTS] = {};
	for (c_uint i = 0; i < count; ++i)
		views[i] = ppBuffers[i] ? ppBuffers[i]->mSRV.Get() : nullptr;

	JunoBindShaderResources(pDevice->mContext.Get(), stage, startSlot, count, views);
}

JUNO_API void JunoSetUnorderedAccessBuffers(JunoDevice* pDevice, c_uint startSlot, c_uint count, JunoBuffer* const* ppBuffers)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(startSlot + count <= JUNO_MAX_UAV_SLOTS);
	JUNO_ASSERT(count == 0 || ppBuffers != nullptr);

	ID3D11UnorderedAccessView* views[JUNO_MAX_UAV_SLOTS] = {};
	for (c_uint i = 0; i < count; ++i)
		views[i] = ppBuffers[i] ? ppBuffers[i]->mUAV.Get() : nullptr;

	pDevice->mContext->CSSetUnorderedAccessViews(startSlot, count, views, nullptr);
}
