#include "pch.h"
#include "JunoInternal.h"

static thread_local JunoErrorCode sLastCode = JunoErrorCode_Ok;
static thread_local HRESULT sLastHResult = S_OK;
static thread_local char sLastMessage[4096] = "";

JunoFatalErrorHandlerFunc RuntimeFatalError = nullptr;


JUNO_API JunoErrorCode JunoSetFatalErrorHandler(JunoFatalErrorHandlerFunc callback)
{
	if (callback == nullptr)
		return JunoErrorCode_InvalidArgument;

	RuntimeFatalError = callback;

	return JunoErrorCode_Ok;
}

JunoErrorCode JunoSetError(JunoErrorCode code, HRESULT hr, const char* pFormat, ...)
{
	va_list args;
	va_start(args, pFormat);
	vsnprintf(sLastMessage, sizeof(sLastMessage), pFormat, args);
	va_end(args);

	if (FAILED(hr))
	{
		size_t length = strlen(sLastMessage);
		snprintf(sLastMessage + length, sizeof(sLastMessage) - length, " (HRESULT 0x%08X)", (unsigned int)hr);
	}

	sLastCode = code;
	sLastHResult = hr;
	return code;
}

JunoErrorCode JunoFailHResult(JunoErrorCode fallback, HRESULT hr, const char* pWhat)
{
	JunoErrorCode code = (hr == DXGI_ERROR_DEVICE_REMOVED || hr == DXGI_ERROR_DEVICE_RESET) ? JunoErrorCode_DeviceLost : fallback;
	return JunoSetError(code, hr, "%s failed", pWhat);
}

JUNO_API const c_char* JunoGetLastErrorMessage(void)
{
	return sLastMessage;
}

JUNO_API JunoErrorCode JunoGetLastErrorCode(void)
{
	return sLastCode;
}

JUNO_API c_int JunoGetLastErrorHResult(void)
{
	return (c_int)sLastHResult;
}

JUNO_API void JunoClearLastError(void)
{
	sLastCode = JunoErrorCode_Ok;
	sLastHResult = S_OK;
	sLastMessage[0] = '\0';
}

JUNO_API void JunoGetInteropLayoutSizes(JunoInteropLayoutSizes* pSizes)
{
	JUNO_ASSERT(pSizes != nullptr);

	pSizes->mJunoDeviceCreateInfo = sizeof(JunoDeviceCreateInfo);
	pSizes->mJunoShaderCreateInfo = sizeof(JunoShaderCreateInfo);
	pSizes->mJunoShaderCompileFromFileInfo = sizeof(JunoShaderCompileFromFileInfo);
	pSizes->mJunoShaderCompileInfo = sizeof(JunoShaderCompileInfo);
	pSizes->mJunoSwapChainCreateInfo = sizeof(JunoSwapChainCreateInfo);
	pSizes->mJunoBufferCreateInfo = sizeof(JunoBufferCreateInfo);
	pSizes->mJunoTextureCreateInfo = sizeof(JunoTextureCreateInfo);
	pSizes->mJunoRegion = sizeof(JunoRegion);
	pSizes->mJunoViewport = sizeof(JunoViewport);
	pSizes->mJunoScissor = sizeof(JunoScissor);
	pSizes->mJunoSamplerCreateInfo = sizeof(JunoSamplerCreateInfo);
	pSizes->mJunoInputElementDescription = sizeof(JunoInputElementDescription);
	pSizes->mJunoBlendDesc = sizeof(JunoBlendDesc);
	pSizes->mJunoRasterizerDesc = sizeof(JunoRasterizerDesc);
	pSizes->mJunoStencilOpDesc = sizeof(JunoStencilOpDesc);
	pSizes->mJunoDepthStencilCreateInfo = sizeof(JunoDepthStencilCreateInfo);

	pSizes->mJunoInteropLayoutSizes = sizeof(JunoInteropLayoutSizes);
}
