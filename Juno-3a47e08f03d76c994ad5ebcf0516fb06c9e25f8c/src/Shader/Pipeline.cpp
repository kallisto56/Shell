#include "pch.h"
#include "JunoInternal.h"

JUNO_API void JunoSetRenderTargets(JunoDevice* pDevice, c_uint count, JunoTexture* const* ppColorTargets, JunoTexture* pDepthTarget)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(count <= JUNO_MAX_RENDER_TARGETS);
	JUNO_ASSERT(count == 0 || ppColorTargets != nullptr);

	ID3D11RenderTargetView* views[JUNO_MAX_RENDER_TARGETS] = {};
	for (c_uint i = 0; i < count; ++i)
	{
		JUNO_ASSERT(ppColorTargets[i] != nullptr);
		JUNO_ASSERT(ppColorTargets[i]->mRTV != nullptr); // Texture must be created with JunoBindFlags_RenderTarget.
		views[i] = ppColorTargets[i]->mRTV.Get();
	}

	ID3D11DepthStencilView* pDsv = nullptr;
	if (pDepthTarget != nullptr)
	{
		JUNO_ASSERT(pDepthTarget->mDSV != nullptr); // Texture must be created with JunoBindFlags_DepthStencil.
		pDsv = pDepthTarget->mDSV.Get();
	}

	pDevice->mContext->OMSetRenderTargets(count, views, pDsv);
}

JUNO_API void JunoSetViewports(JunoDevice* pDevice, c_uint count, const JunoViewport* pViewports)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(count > 0 && count <= D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE);
	JUNO_ASSERT(pViewports != nullptr);
	pDevice->mContext->RSSetViewports(count, reinterpret_cast<const D3D11_VIEWPORT*>(pViewports));
}

JUNO_API void JunoSetScissorRects(JunoDevice* pDevice, const JunoScissor* pScissors, c_uint count)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(count > 0 && count <= D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE);
	JUNO_ASSERT(pScissors != nullptr);
	pDevice->mContext->RSSetScissorRects(count, reinterpret_cast<const D3D11_RECT*>(pScissors));
}

JUNO_API void JunoSetPrimitiveTopology(JunoDevice* pDevice, JunoPrimitiveTopology topology)
{
	JUNO_ASSERT(pDevice != nullptr);
	pDevice->mContext->IASetPrimitiveTopology((D3D11_PRIMITIVE_TOPOLOGY)topology);
}
