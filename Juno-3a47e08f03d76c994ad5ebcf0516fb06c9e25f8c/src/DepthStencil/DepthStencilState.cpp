#include "pch.h"
#include "JunoInternal.h"

static D3D11_DEPTH_STENCILOP_DESC ToD3D(const JunoStencilOpDesc& op)
{
	D3D11_DEPTH_STENCILOP_DESC d = {};
	d.StencilFailOp = (D3D11_STENCIL_OP)op.mStencilFailOp;
	d.StencilDepthFailOp = (D3D11_STENCIL_OP)op.mStencilDepthFailOp;
	d.StencilPassOp = (D3D11_STENCIL_OP)op.mStencilPassOp;
	d.StencilFunc = (D3D11_COMPARISON_FUNC)op.mStencilFunc;
	return d;
}

JUNO_API JunoErrorCode JunoCreateDepthStencilState(const JunoDepthStencilCreateInfo* pCreateInfo, JunoDepthStencilState** ppState)
{
	JUNO_ASSERT(pCreateInfo != nullptr);
	JUNO_ASSERT(pCreateInfo->mDevice != nullptr);
	JUNO_ASSERT(ppState != nullptr);
	*ppState = nullptr;

	D3D11_DEPTH_STENCIL_DESC dd = {};
	dd.DepthEnable = pCreateInfo->bDepthEnable;
	dd.DepthWriteMask = pCreateInfo->bDepthWriteEnable ? D3D11_DEPTH_WRITE_MASK_ALL : D3D11_DEPTH_WRITE_MASK_ZERO;
	dd.DepthFunc = (D3D11_COMPARISON_FUNC)pCreateInfo->mDepthFunc;
	dd.StencilEnable = pCreateInfo->bStencilEnable;
	dd.StencilReadMask = pCreateInfo->mStencilReadMask;
	dd.StencilWriteMask = pCreateInfo->mStencilWriteMask;
	dd.FrontFace = ToD3D(pCreateInfo->mFrontFace);
	dd.BackFace = ToD3D(pCreateInfo->mBackFace);

	JunoDepthStencilState* pState = new (std::nothrow) JunoDepthStencilState();
	JUNO_REQUIRE_ALLOC(pState);

	HRESULT hr = pCreateInfo->mDevice->mDevice->CreateDepthStencilState(&dd, &pState->mState);
	if (FAILED(hr))
	{
		delete pState;
		return JunoFailHResult(JunoErrorCode_StateCreationFailed, hr, "ID3D11Device::CreateDepthStencilState");
	}

	*ppState = pState;
	return JunoErrorCode_Ok;
}

JUNO_API void JunoDestroyDepthStencilState(JunoDepthStencilState* pState)
{
	delete pState;
}

JUNO_API void JunoSetDepthStencilState(JunoDevice* pDevice, JunoDepthStencilState* pState, c_uint stencilRef)
{
	JUNO_ASSERT(pDevice != nullptr);
	pDevice->mContext->OMSetDepthStencilState(pState ? pState->mState.Get() : nullptr, stencilRef);
}
