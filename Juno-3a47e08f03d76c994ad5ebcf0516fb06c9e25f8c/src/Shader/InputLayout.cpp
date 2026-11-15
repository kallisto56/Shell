#include "pch.h"
#include "JunoInternal.h"

JUNO_API JunoErrorCode JunoCreateInputLayout(JunoDevice* pDevice, const JunoInputElementDescription* pElements, c_uint elementCount, const void* pVertexShaderBytecode, c_size vertexShaderBytecodeSize, JunoInputLayout** ppLayout)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(pElements != nullptr);
	JUNO_ASSERT(elementCount > 0);
	JUNO_ASSERT(pVertexShaderBytecode != nullptr);
	JUNO_ASSERT(vertexShaderBytecodeSize > 0);
	JUNO_ASSERT(ppLayout != nullptr);
	*ppLayout = nullptr;

	std::vector<D3D11_INPUT_ELEMENT_DESC> elements(elementCount);
	for (c_uint i = 0; i < elementCount; ++i)
	{
		JUNO_ASSERT(pElements[i].mSemanticName != nullptr);

		D3D11_INPUT_ELEMENT_DESC& e = elements[i];
		e.SemanticName = pElements[i].mSemanticName;
		e.SemanticIndex = pElements[i].mSemanticIndex;
		e.Format = (DXGI_FORMAT)pElements[i].mFormat;
		e.InputSlot = pElements[i].mInputSlot;
		e.AlignedByteOffset = pElements[i].mAlignedByteOffset;
		e.InputSlotClass = (D3D11_INPUT_CLASSIFICATION)pElements[i].mInputSlotClass;
		e.InstanceDataStepRate = pElements[i].mInstanceDataStepRate;
	}

	JunoInputLayout* pLayout = new (std::nothrow) JunoInputLayout();
	JUNO_REQUIRE_ALLOC(pLayout);

	HRESULT hr = pDevice->mDevice->CreateInputLayout(elements.data(), elementCount, pVertexShaderBytecode, vertexShaderBytecodeSize, &pLayout->mLayout);
	if (FAILED(hr))
	{
		delete pLayout;
		return JunoFailHResult(JunoErrorCode_InputLayoutCreationFailed, hr, "ID3D11Device::CreateInputLayout");
	}

	*ppLayout = pLayout;
	return JunoErrorCode_Ok;
}

JUNO_API void JunoDestroyInputLayout(JunoInputLayout* pLayout)
{
	delete pLayout;
}

JUNO_API void JunoSetInputLayout(JunoDevice* pDevice, JunoInputLayout* pLayout)
{
	JUNO_ASSERT(pDevice != nullptr);
	pDevice->mContext->IASetInputLayout(pLayout ? pLayout->mLayout.Get() : nullptr);
}
