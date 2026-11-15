#include "pch.h"
#include "JunoInternal.h"

static JunoErrorCode CompileFailed(HRESULT hr, ID3DBlob* pErrors)
{
	const char* pText = pErrors ? (const char*)pErrors->GetBufferPointer() : "No compiler output.";
	return JunoSetError(JunoErrorCode_ShaderCompileFailed, hr, "Shader compilation failed:\n%s", pText);
}

JUNO_API JunoErrorCode JunoCompileShader(const JunoShaderCompileInfo* pCompileInfo, JunoBlob** ppBlob)
{
	JUNO_ASSERT(pCompileInfo != nullptr);
	JUNO_ASSERT(pCompileInfo->mSource != nullptr);
	JUNO_ASSERT(pCompileInfo->mSourceLength > 0);
	JUNO_ASSERT(pCompileInfo->mEntryPoint != nullptr);
	JUNO_ASSERT(pCompileInfo->mTarget != nullptr);
	JUNO_ASSERT(ppBlob != nullptr);
	*ppBlob = nullptr;

	ComPtr<ID3DBlob> code;
	ComPtr<ID3DBlob> errors;
	HRESULT hr = D3DCompile(pCompileInfo->mSource, pCompileInfo->mSourceLength, pCompileInfo->mSourceName, nullptr, nullptr, pCompileInfo->mEntryPoint, pCompileInfo->mTarget, pCompileInfo->mCompileFlags, 0, &code, &errors);
	if (FAILED(hr))
		return CompileFailed(hr, errors.Get());

	JunoBlob* pBlob = new (std::nothrow) JunoBlob();
	JUNO_REQUIRE_ALLOC(pBlob);
	pBlob->mBlob = code;
	*ppBlob = pBlob;
	return JunoErrorCode_Ok;
}

JUNO_API JunoErrorCode JunoCompileShaderFromFile(const JunoShaderCompileFromFileInfo* pCompileInfo, JunoBlob** ppBlob)
{
	JUNO_ASSERT(pCompileInfo != nullptr);
	JUNO_ASSERT(pCompileInfo->mPath != nullptr);
	JUNO_ASSERT(pCompileInfo->mEntryPoint != nullptr);
	JUNO_ASSERT(pCompileInfo->mTarget != nullptr);
	JUNO_ASSERT(ppBlob != nullptr);
	*ppBlob = nullptr;

	ComPtr<ID3DBlob> code;
	ComPtr<ID3DBlob> errors;
	HRESULT hr = D3DCompileFromFile(pCompileInfo->mPath, nullptr, D3D_COMPILE_STANDARD_FILE_INCLUDE, pCompileInfo->mEntryPoint, pCompileInfo->mTarget, pCompileInfo->mCompileFlags, 0, &code, &errors);
	if (hr == HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND) || hr == HRESULT_FROM_WIN32(ERROR_PATH_NOT_FOUND))
		return JunoSetError(JunoErrorCode_FileNotFound, hr, "Shader file not found");
	if (FAILED(hr))
		return CompileFailed(hr, errors.Get());

	JunoBlob* pBlob = new (std::nothrow) JunoBlob();
	JUNO_REQUIRE_ALLOC(pBlob);
	pBlob->mBlob = code;
	*ppBlob = pBlob;
	return JunoErrorCode_Ok;
}

JUNO_API const void* JunoGetBlobData(JunoBlob* pBlob)
{
	JUNO_ASSERT(pBlob != nullptr);
	return pBlob->mBlob->GetBufferPointer();
}

JUNO_API c_size JunoGetBlobSize(JunoBlob* pBlob)
{
	JUNO_ASSERT(pBlob != nullptr);
	return (c_size)pBlob->mBlob->GetBufferSize();
}

JUNO_API void JunoDestroyBlob(JunoBlob* pBlob)
{
	delete pBlob;
}

JUNO_API JunoErrorCode JunoCreateShader(JunoShaderCreateInfo* pCreateInfo, JunoShader** ppShader)
{
	JUNO_ASSERT(pCreateInfo != nullptr);
	JUNO_ASSERT(pCreateInfo->mDevice != nullptr);
	JUNO_ASSERT(pCreateInfo->mBytecode != nullptr);
	JUNO_ASSERT(pCreateInfo->mBytecodeSize > 0);
	JUNO_ASSERT(ppShader != nullptr);
	*ppShader = nullptr;

	JunoShader* pShader = new (std::nothrow) JunoShader();
	JUNO_REQUIRE_ALLOC(pShader);
	pShader->mStage = pCreateInfo->mStage;

	ID3D11Device* pNative = pCreateInfo->mDevice->mDevice.Get();
	HRESULT hr = E_INVALIDARG;

	switch (pCreateInfo->mStage)
	{
	case JunoShaderStage_Vertex:
	{
		ComPtr<ID3D11VertexShader> shader;
		hr = pNative->CreateVertexShader(pCreateInfo->mBytecode, pCreateInfo->mBytecodeSize, nullptr, &shader);
		pShader->mShader = shader;
		break;
	}
	case JunoShaderStage_Pixel:
	{
		ComPtr<ID3D11PixelShader> shader;
		hr = pNative->CreatePixelShader(pCreateInfo->mBytecode, pCreateInfo->mBytecodeSize, nullptr, &shader);
		pShader->mShader = shader;
		break;
	}
	case JunoShaderStage_Geometry:
	{
		ComPtr<ID3D11GeometryShader> shader;
		hr = pNative->CreateGeometryShader(pCreateInfo->mBytecode, pCreateInfo->mBytecodeSize, nullptr, &shader);
		pShader->mShader = shader;
		break;
	}
	case JunoShaderStage_Compute:
	{
		ComPtr<ID3D11ComputeShader> shader;
		hr = pNative->CreateComputeShader(pCreateInfo->mBytecode, pCreateInfo->mBytecodeSize, nullptr, &shader);
		pShader->mShader = shader;
		break;
	}
	default:
		RuntimeFatalError("Unknown shader stage", __FILE__, __LINE__);
		break;
	}

	if (FAILED(hr))
	{
		delete pShader;
		return JunoFailHResult(JunoErrorCode_ShaderCreationFailed, hr, "ID3D11Device::Create*Shader");
	}

	*ppShader = pShader;
	return JunoErrorCode_Ok;
}

JUNO_API void JunoDestroyShader(JunoShader* pShader)
{
	delete pShader;
}

JUNO_API void JunoSetShader(JunoDevice* pDevice, JunoShader* pShader)
{
	JUNO_ASSERT(pDevice != nullptr);
	JUNO_ASSERT(pShader != nullptr);

	ID3D11DeviceChild* pNative = pShader->mShader.Get();
	ID3D11DeviceContext* pCtx = pDevice->mContext.Get();

	switch (pShader->mStage)
	{
	case JunoShaderStage_Vertex: pCtx->VSSetShader(static_cast<ID3D11VertexShader*>(pNative), nullptr, 0); break;
	case JunoShaderStage_Pixel: pCtx->PSSetShader(static_cast<ID3D11PixelShader*>(pNative), nullptr, 0); break;
	case JunoShaderStage_Geometry: pCtx->GSSetShader(static_cast<ID3D11GeometryShader*>(pNative), nullptr, 0); break;
	case JunoShaderStage_Compute: pCtx->CSSetShader(static_cast<ID3D11ComputeShader*>(pNative), nullptr, 0); break;
	default: RuntimeFatalError("Unknown shader stage", __FILE__, __LINE__); break;
	}
}

JUNO_API void JunoUnsetShader(JunoDevice* pDevice, JunoShaderStage stage)
{
	JUNO_ASSERT(pDevice != nullptr);

	ID3D11DeviceContext* pCtx = pDevice->mContext.Get();
	switch (stage)
	{
	case JunoShaderStage_Vertex: pCtx->VSSetShader(nullptr, nullptr, 0); break;
	case JunoShaderStage_Pixel: pCtx->PSSetShader(nullptr, nullptr, 0); break;
	case JunoShaderStage_Geometry: pCtx->GSSetShader(nullptr, nullptr, 0); break;
	case JunoShaderStage_Compute: pCtx->CSSetShader(nullptr, nullptr, 0); break;
	default: RuntimeFatalError("Unknown shader stage", __FILE__, __LINE__); break;
	}
}
