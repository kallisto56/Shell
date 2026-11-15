#include "pch.h"
#include "JunoInternal.h"

static HRESULT TryCreateDevice(IDXGIAdapter* pAdapter, D3D_DRIVER_TYPE driverType, UINT flags, ID3D11Device** ppDevice, D3D_FEATURE_LEVEL* pLevel, ID3D11DeviceContext** ppContext)
{
	static const D3D_FEATURE_LEVEL levels[] =
	{
		D3D_FEATURE_LEVEL_11_1,
		D3D_FEATURE_LEVEL_11_0,
		D3D_FEATURE_LEVEL_10_1,
		D3D_FEATURE_LEVEL_10_0,
	};

	HRESULT hr = D3D11CreateDevice(pAdapter, driverType, nullptr, flags, levels, _countof(levels), D3D11_SDK_VERSION, ppDevice, pLevel, ppContext);
	if (hr == E_INVALIDARG)
	{
		// Runtime does not know feature level 11.1.
		hr = D3D11CreateDevice(pAdapter, driverType, nullptr, flags, levels + 1, _countof(levels) - 1, D3D11_SDK_VERSION, ppDevice, pLevel, ppContext);
	}
	return hr;
}

JUNO_API JunoErrorCode JunoCreateDevice(const JunoDeviceCreateInfo* pCreateInfo, JunoDevice** ppDevice)
{
	JUNO_ASSERT(pCreateInfo != nullptr);
	JUNO_ASSERT(pCreateInfo != nullptr);
	JUNO_ASSERT(ppDevice != nullptr);
	*ppDevice = nullptr;

	ComPtr<IDXGIFactory1> factory1;
	HRESULT hr = CreateDXGIFactory1(IID_PPV_ARGS(&factory1));
	if (FAILED(hr))
		return JunoFailHResult(JunoErrorCode_DeviceCreationFailed, hr, "CreateDXGIFactory1");

	ComPtr<IDXGIAdapter1> adapter;
	D3D_DRIVER_TYPE driverType = D3D_DRIVER_TYPE_HARDWARE;
	if (pCreateInfo->mAdapterIndex >= 0)
	{
		hr = factory1->EnumAdapters1((UINT)pCreateInfo->mAdapterIndex, &adapter);
		if (FAILED(hr))
			return JunoSetError(JunoErrorCode_InvalidArgument, hr, "Adapter index %d does not exist", pCreateInfo->mAdapterIndex);
		driverType = D3D_DRIVER_TYPE_UNKNOWN;
	}

	UINT flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
	if (pCreateInfo->bDebug)
		flags |= D3D11_CREATE_DEVICE_DEBUG;

	ComPtr<ID3D11Device> device;
	ComPtr<ID3D11DeviceContext> context;
	D3D_FEATURE_LEVEL level = D3D_FEATURE_LEVEL_11_0;

	hr = TryCreateDevice(adapter.Get(), driverType, flags, &device, &level, &context);
	if (FAILED(hr) && (flags & D3D11_CREATE_DEVICE_DEBUG))
	{
		// The debug layer is an optional Windows feature. Retry without it.
		flags &= ~D3D11_CREATE_DEVICE_DEBUG;
		hr = TryCreateDevice(adapter.Get(), driverType, flags, &device, &level, &context);
	}
	if (FAILED(hr) && pCreateInfo->bAllowWarp)
		hr = TryCreateDevice(nullptr, D3D_DRIVER_TYPE_WARP, flags, &device, &level, &context);
	if (FAILED(hr))
		return JunoFailHResult(JunoErrorCode_DeviceCreationFailed, hr, "D3D11CreateDevice");

	// Get the factory that belongs to the adapter the device was created on.
	ComPtr<IDXGIDevice> dxgiDevice;
	ComPtr<IDXGIAdapter> dxgiAdapter;
	ComPtr<IDXGIFactory2> factory2;
	hr = device.As(&dxgiDevice);
	if (SUCCEEDED(hr))
		hr = dxgiDevice->GetAdapter(&dxgiAdapter);
	if (SUCCEEDED(hr))
		hr = dxgiAdapter->GetParent(IID_PPV_ARGS(&factory2));
	if (FAILED(hr))
		return JunoFailHResult(JunoErrorCode_DeviceCreationFailed, hr, "Querying IDXGIFactory2");

	JunoDevice* pNew = new (std::nothrow) JunoDevice();
	JUNO_REQUIRE_ALLOC(pNew);

	pNew->mDevice = device;
	pNew->mContext = context;
	pNew->mFactory = factory2;
	pNew->mFeatureLevel = level;

	ComPtr<IDXGIFactory5> factory5;
	if (SUCCEEDED(factory2.As(&factory5)))
	{
		BOOL allowTearing = FALSE;
		if (SUCCEEDED(factory5->CheckFeatureSupport(DXGI_FEATURE_PRESENT_ALLOW_TEARING, &allowTearing, sizeof(allowTearing))))
			pNew->bTearingSupported = allowTearing != FALSE;
	}

	*ppDevice = pNew;
	return JunoErrorCode_Ok;
}

JUNO_API void JunoDestroyDevice(JunoDevice* pDevice)
{
	if (pDevice == nullptr)
		return;

	if (pDevice->mContext)
	{
		pDevice->mContext->ClearState();
		pDevice->mContext->Flush();
	}
	delete pDevice;
}

JUNO_API void JunoFlush(JunoDevice* pDevice)
{
	JUNO_ASSERT(pDevice != nullptr);
	pDevice->mContext->Flush();
}

JUNO_API void JunoClearState(JunoDevice* pDevice)
{
	JUNO_ASSERT(pDevice != nullptr);
	pDevice->mContext->ClearState();
}
