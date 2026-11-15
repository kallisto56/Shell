namespace Juno;


using System;
using System.Diagnostics;
using System.Interop;


[CRepr]
struct Device
{
	public ComPtr<ID3D11Device> mDevice;
	public ComPtr<ID3D11DeviceContext> mContext;
	public ComPtr<IDXGIFactory2> mFactory;
	public D3D_FEATURE_LEVEL mFeatureLevel;
	public c_bool bTearingSupported = false;

	[CRepr]
	public struct CreateInfo
	{
		public c_bool bDebug = false;
		public c_bool bAllowWarp = true;
		public c_int mAdapterIndex = 0;
	}

	[CRepr]
	public enum D3D_FEATURE_LEVEL
	{
	    D3D_FEATURE_LEVEL_1_0_GENERIC	= 0x100,
	    D3D_FEATURE_LEVEL_1_0_CORE	= 0x1000,
	    D3D_FEATURE_LEVEL_9_1	= 0x9100,
	    D3D_FEATURE_LEVEL_9_2	= 0x9200,
	    D3D_FEATURE_LEVEL_9_3	= 0x9300,
	    D3D_FEATURE_LEVEL_10_0	= 0xa000,
	    D3D_FEATURE_LEVEL_10_1	= 0xa100,
	    D3D_FEATURE_LEVEL_11_0	= 0xb000,
	    D3D_FEATURE_LEVEL_11_1	= 0xb100,
	    D3D_FEATURE_LEVEL_12_0	= 0xc000,
	    D3D_FEATURE_LEVEL_12_1	= 0xc100,
	    D3D_FEATURE_LEVEL_12_2	= 0xc200
	}
}
