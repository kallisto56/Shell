#include "pch.h"
#include "JunoInternal.h"

JUNO_API JunoErrorCode JunoCreateRasterizerState(JunoDevice* pDevice, const JunoRasterizerDesc* pDesc, JunoRasterizerState** ppState)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(pDesc != nullptr);
	JUNO_ASSERT(ppState != nullptr);
	*ppState = nullptr;

	D3D11_RASTERIZER_DESC rd = {};
	rd.FillMode = (D3D11_FILL_MODE)pDesc->mFillMode;
	rd.CullMode = (D3D11_CULL_MODE)pDesc->mCullMode;
	rd.FrontCounterClockwise = pDesc->bFrontCounterClockwise;
	rd.DepthBias = pDesc->mDepthBias;
	rd.DepthBiasClamp = pDesc->mDepthBiasClamp;
	rd.SlopeScaledDepthBias = pDesc->mSlopeScaledDepthBias;
	rd.DepthClipEnable = pDesc->bDepthClipEnable;
	rd.ScissorEnable = pDesc->bScissorEnable;
	rd.MultisampleEnable = pDesc->bMultisampleEnable;
	rd.AntialiasedLineEnable = pDesc->bAntialiasedLineEnable;

	JunoRasterizerState* pState = new (std::nothrow) JunoRasterizerState();
	JUNO_REQUIRE_ALLOC(pState);

	HRESULT hr = pDevice->mDevice->CreateRasterizerState(&rd, &pState->mState);
	if (FAILED(hr))
	{
		delete pState;
		return JunoFailHResult(JunoErrorCode_StateCreationFailed, hr, "ID3D11Device::CreateRasterizerState");
	}

	*ppState = pState;
	return JunoErrorCode_Ok;
}

JUNO_API void JunoDestroyRasterizerState(JunoRasterizerState* pState)
{
	delete pState;
}

JUNO_API void JunoSetRasterizerState(JunoDevice* pDevice, JunoRasterizerState* pState)
{
	JUNO_ASSERT(pDevice != nullptr);
	pDevice->mContext->RSSetState(pState ? pState->mState.Get() : nullptr);
}
