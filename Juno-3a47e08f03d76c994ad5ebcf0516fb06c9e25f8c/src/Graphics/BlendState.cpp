#include "pch.h"
#include "JunoInternal.h"

JUNO_API JunoErrorCode JunoCreateBlendState(JunoDevice* pDevice, const JunoBlendDesc* pDesc, JunoBlendState** ppState)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(pDesc != nullptr);
	JUNO_ASSERT(ppState != nullptr);
	*ppState = nullptr;

	D3D11_BLEND_DESC bd = {};
	bd.AlphaToCoverageEnable = pDesc->bAlphaToCoverage;
	bd.IndependentBlendEnable = FALSE; // RenderTarget[0] is used for every render target.

	D3D11_RENDER_TARGET_BLEND_DESC& rt = bd.RenderTarget[0];
	rt.BlendEnable = pDesc->bBlendEnable;
	rt.SrcBlend = (D3D11_BLEND)pDesc->mSrcBlend;
	rt.DestBlend = (D3D11_BLEND)pDesc->mDestBlend;
	rt.BlendOp = (D3D11_BLEND_OP)pDesc->mBlendOp;
	rt.SrcBlendAlpha = (D3D11_BLEND)pDesc->mSrcBlendAlpha;
	rt.DestBlendAlpha = (D3D11_BLEND)pDesc->mDestBlendAlpha;
	rt.BlendOpAlpha = (D3D11_BLEND_OP)pDesc->mBlendOpAlpha;
	rt.RenderTargetWriteMask = pDesc->mWriteMask;

	JunoBlendState* pState = new (std::nothrow) JunoBlendState();
	JUNO_REQUIRE_ALLOC(pState);

	HRESULT hr = pDevice->mDevice->CreateBlendState(&bd, &pState->mState);
	if (FAILED(hr))
	{
		delete pState;
		return JunoFailHResult(JunoErrorCode_StateCreationFailed, hr, "ID3D11Device::CreateBlendState");
	}

	*ppState = pState;
	return JunoErrorCode_Ok;
}

JUNO_API void JunoDestroyBlendState(JunoBlendState* pState)
{
	delete pState;
}

JUNO_API void JunoSetBlendState(JunoDevice* pDevice, JunoBlendState* pState, const float* pBlendFactor, c_uint sampleMask)
{
	JUNO_ASSERT(pDevice != nullptr);
	pDevice->mContext->OMSetBlendState(pState ? pState->mState.Get() : nullptr, pBlendFactor, sampleMask);
}
