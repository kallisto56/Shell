#include "pch.h"
#include "JunoInternal.h"

static void ResetTexture(JunoTexture& texture)
{
	texture.mTexture.Reset();
	texture.mSRV.Reset();
	texture.mRTV.Reset();
	texture.mDSV.Reset();
	texture.mUAV.Reset();
}

static void GetClientSize(HWND hwnd, UINT* pWidth, UINT* pHeight)
{
	RECT rc = {};
	GetClientRect(hwnd, &rc);
	*pWidth = (UINT)(rc.right - rc.left);
	*pHeight = (UINT)(rc.bottom - rc.top);
}

static JunoErrorCode CreateBuffers(JunoSwapChain* pSC)
{
	ID3D11Device* pDevice = pSC->mDevice->mDevice.Get();

	ComPtr<ID3D11Texture2D> buffer;
	HRESULT hr = pSC->mSwapChain->GetBuffer(0, IID_PPV_ARGS(&buffer));
	if (FAILED(hr))
		return JunoFailHResult(JunoErrorCode_SwapChainCreationFailed, hr, "IDXGISwapChain1::GetBuffer");

	D3D11_TEXTURE2D_DESC td = {};
	buffer->GetDesc(&td);

	hr = pDevice->CreateRenderTargetView(buffer.Get(), nullptr, &pSC->mBackBuffer.mRTV);
	if (FAILED(hr))
		return JunoFailHResult(JunoErrorCode_SwapChainCreationFailed, hr, "CreateRenderTargetView (back buffer)");

	JunoTexture& back = pSC->mBackBuffer;
	back.mTexture = buffer;
	back.bOwnedBySwapChain = true;
	back.mCreateInfo.mWidth = td.Width;
	back.mCreateInfo.mHeight = td.Height;
	back.mCreateInfo.mMipLevels = 1;
	back.mCreateInfo.mArraySize = 1;
	back.mCreateInfo.mSampleCount = 1;
	back.mCreateInfo.mFormat = (JunoPixelFormat)td.Format;
	back.mCreateInfo.mUsage = JunoUsage_Default;
	back.mCreateInfo.mBindFlags = JunoBindFlags_RenderTarget;

	if (pSC->mDesc.mDepthFormat != JunoPixelFormat_Unknown)
	{
		D3D11_TEXTURE2D_DESC dd = {};
		dd.Width = td.Width;
		dd.Height = td.Height;
		dd.MipLevels = 1;
		dd.ArraySize = 1;
		dd.Format = (DXGI_FORMAT)pSC->mDesc.mDepthFormat;
		dd.SampleDesc.Count = 1;
		dd.Usage = D3D11_USAGE_DEFAULT;
		dd.BindFlags = D3D11_BIND_DEPTH_STENCIL;

		JunoTexture& depth = pSC->mDepthBuffer;
		hr = pDevice->CreateTexture2D(&dd, nullptr, &depth.mTexture);
		if (FAILED(hr))
			return JunoFailHResult(JunoErrorCode_SwapChainCreationFailed, hr, "CreateTexture2D (depth buffer)");
		hr = pDevice->CreateDepthStencilView(depth.mTexture.Get(), nullptr, &depth.mDSV);
		if (FAILED(hr))
			return JunoFailHResult(JunoErrorCode_SwapChainCreationFailed, hr, "CreateDepthStencilView (depth buffer)");

		depth.bOwnedBySwapChain = true;
		depth.mCreateInfo.mWidth = dd.Width;
		depth.mCreateInfo.mHeight = dd.Height;
		depth.mCreateInfo.mMipLevels = 1;
		depth.mCreateInfo.mArraySize = 1;
		depth.mCreateInfo.mSampleCount = 1;
		depth.mCreateInfo.mFormat = pSC->mDesc.mDepthFormat;
		depth.mCreateInfo.mUsage = JunoUsage_Default;
		depth.mCreateInfo.mBindFlags = JunoBindFlags_DepthStencil;
	}

	return JunoErrorCode_Ok;
}

static JunoErrorCode FailAndDelete(JunoSwapChain* pSC, HRESULT hr, const char* pWhat)
{
	JunoErrorCode code = JunoFailHResult(JunoErrorCode_SwapChainCreationFailed, hr, pWhat);
	delete pSC;
	return code;
}

JUNO_API JunoErrorCode JunoCreateSwapChain(const JunoSwapChainCreateInfo* pCreateInfo, JunoSwapChain** ppSwapChain)
{
	JUNO_ASSERT(pCreateInfo != nullptr);
	JUNO_ASSERT(pCreateInfo->mDevice != nullptr);
	JUNO_ASSERT(ppSwapChain != nullptr);
	*ppSwapChain = nullptr;
	JUNO_ASSERT(pCreateInfo->mWindow != nullptr);

	HWND hwnd = (HWND)pCreateInfo->mWindow;
	JUNO_ASSERT(IsWindow(hwnd));

	JunoSwapChain* pSC = new (std::nothrow) JunoSwapChain();
	JUNO_ASSERT(pSC);

	pSC->mDevice = pCreateInfo->mDevice;
	pSC->mHwnd = hwnd;
	pSC->mDesc = *pCreateInfo;
	if (pSC->mDesc.mFormat == JunoPixelFormat_Unknown)
		pSC->mDesc.mFormat = JunoPixelFormat_B8G8R8A8_UNorm;
	if (pSC->mDesc.mBufferCount < 2)
		pSC->mDesc.mBufferCount = 2;
	pSC->bTearing = pCreateInfo->bAllowTearing && pCreateInfo->mDevice->bTearingSupported && !pCreateInfo->bComposition;
	pSC->mFlags = pSC->bTearing ? DXGI_SWAP_CHAIN_FLAG_ALLOW_TEARING : 0;

	UINT width = pCreateInfo->mWidth;
	UINT height = pCreateInfo->mHeight;
	if (width == 0 || height == 0)
		GetClientSize(hwnd, &width, &height);
	if (width == 0) width = 1;
	if (height == 0) height = 1;

	DXGI_SWAP_CHAIN_DESC1 sd = {};
	sd.Width = width;
	sd.Height = height;
	sd.Format = (DXGI_FORMAT)pSC->mDesc.mFormat;
	sd.SampleDesc.Count = 1;
	sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT | DXGI_USAGE_SHADER_INPUT;
	sd.BufferCount = pSC->mDesc.mBufferCount;
	sd.Scaling = DXGI_SCALING_STRETCH;
	sd.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
	sd.AlphaMode = pCreateInfo->bComposition ? DXGI_ALPHA_MODE_PREMULTIPLIED : DXGI_ALPHA_MODE_IGNORE;
	sd.Flags = pSC->mFlags;

	ID3D11Device* pNativeDevice = pCreateInfo->mDevice->mDevice.Get();
	HRESULT hr;

	if (pCreateInfo->bComposition)
	{
		ComPtr<IDXGIDevice> dxgiDevice;
		hr = pCreateInfo->mDevice->mDevice.As(&dxgiDevice);
		if (FAILED(hr)) return FailAndDelete(pSC, hr, "Querying IDXGIDevice");

		hr = pCreateInfo->mDevice->mFactory->CreateSwapChainForComposition(pNativeDevice, &sd, nullptr, &pSC->mSwapChain);
		if (FAILED(hr)) return FailAndDelete(pSC, hr, "IDXGIFactory2::CreateSwapChainForComposition");

		hr = DCompositionCreateDevice(dxgiDevice.Get(), IID_PPV_ARGS(&pSC->mDCompDevice));
		if (FAILED(hr)) return FailAndDelete(pSC, hr, "DCompositionCreateDevice");
		hr = pSC->mDCompDevice->CreateTargetForHwnd(hwnd, TRUE, &pSC->mDCompTarget);
		if (FAILED(hr)) return FailAndDelete(pSC, hr, "IDCompositionDevice::CreateTargetForHwnd");
		hr = pSC->mDCompDevice->CreateVisual(&pSC->mDCompVisual);
		if (FAILED(hr)) return FailAndDelete(pSC, hr, "IDCompositionDevice::CreateVisual");
		hr = pSC->mDCompVisual->SetContent(pSC->mSwapChain.Get());
		if (FAILED(hr)) return FailAndDelete(pSC, hr, "IDCompositionVisual::SetContent");
		hr = pSC->mDCompTarget->SetRoot(pSC->mDCompVisual.Get());
		if (FAILED(hr)) return FailAndDelete(pSC, hr, "IDCompositionTarget::SetRoot");
		hr = pSC->mDCompDevice->Commit();
		if (FAILED(hr)) return FailAndDelete(pSC, hr, "IDCompositionDevice::Commit");
	}
	else
	{
		hr = pCreateInfo->mDevice->mFactory->CreateSwapChainForHwnd(pNativeDevice, hwnd, &sd, nullptr, nullptr, &pSC->mSwapChain);
		if (FAILED(hr)) return FailAndDelete(pSC, hr, "IDXGIFactory2::CreateSwapChainForHwnd");

		// Alt+Enter fullscreen toggling is left to the application.
		pCreateInfo->mDevice->mFactory->MakeWindowAssociation(hwnd, DXGI_MWA_NO_ALT_ENTER);
	}

	JunoErrorCode code = CreateBuffers(pSC);
	if (code != JunoErrorCode_Ok)
	{
		delete pSC;
		return code;
	}

	*ppSwapChain = pSC;
	return JunoErrorCode_Ok;
}

JUNO_API void JunoDestroySwapChain(JunoSwapChain* pSwapChain)
{
	if (pSwapChain == nullptr)
		return;

	pSwapChain->mDevice->mContext->OMSetRenderTargets(0, nullptr, nullptr);
	pSwapChain->mDevice->mContext->Flush();
	delete pSwapChain;
}

JUNO_API JunoErrorCode JunoResizeSwapChain(JunoSwapChain* pSwapChain, c_uint width, c_uint height)
{
	JUNO_ASSERT(pSwapChain != nullptr);

	if (width == 0 || height == 0)
		GetClientSize(pSwapChain->mHwnd, &width, &height);
	if (width == 0 || height == 0)
		return JunoErrorCode_Ok; // Minimized. Nothing to do.

	ID3D11DeviceContext* pCtx = pSwapChain->mDevice->mContext.Get();
	pCtx->OMSetRenderTargets(0, nullptr, nullptr);
	ResetTexture(pSwapChain->mBackBuffer);
	ResetTexture(pSwapChain->mDepthBuffer);
	pCtx->Flush();

	HRESULT hr = pSwapChain->mSwapChain->ResizeBuffers(0, width, height, DXGI_FORMAT_UNKNOWN, pSwapChain->mFlags);
	if (FAILED(hr))
		return JunoFailHResult(JunoErrorCode_SwapChainResizeFailed, hr, "IDXGISwapChain1::ResizeBuffers");

	JunoErrorCode code = CreateBuffers(pSwapChain);
	if (code != JunoErrorCode_Ok)
		return JunoSetError(JunoErrorCode_SwapChainResizeFailed, S_OK, "Re-creating buffers after resize failed: %s", JunoGetLastErrorMessage());
	return JunoErrorCode_Ok;
}

JUNO_API JunoErrorCode JunoPresent(JunoSwapChain* pSwapChain, c_bool bVSync)
{
	JUNO_ASSERT(pSwapChain != nullptr);

	UINT syncInterval = bVSync ? 1 : 0;
	UINT flags = (!bVSync && pSwapChain->bTearing) ? DXGI_PRESENT_ALLOW_TEARING : 0;

	HRESULT hr = pSwapChain->mSwapChain->Present(syncInterval, flags);
	if (hr == DXGI_ERROR_DEVICE_REMOVED || hr == DXGI_ERROR_DEVICE_RESET)
	{
		HRESULT reason = pSwapChain->mDevice->mDevice->GetDeviceRemovedReason();
		return JunoSetError(JunoErrorCode_DeviceLost, hr, "Device lost during Present, removed reason 0x%08X", (unsigned int)reason);
	}
	if (FAILED(hr))
		return JunoFailHResult(JunoErrorCode_PresentFailed, hr, "IDXGISwapChain1::Present");
	return JunoErrorCode_Ok;
}

JUNO_API JunoTexture* JunoGetBackBuffer(JunoSwapChain* pSwapChain)
{
	JUNO_ASSERT(pSwapChain != nullptr);
	return &pSwapChain->mBackBuffer;
}

JUNO_API JunoTexture* JunoGetDepthBuffer(JunoSwapChain* pSwapChain)
{
	JUNO_ASSERT(pSwapChain != nullptr);
	return pSwapChain->mDepthBuffer.mDSV ? &pSwapChain->mDepthBuffer : nullptr;
}
