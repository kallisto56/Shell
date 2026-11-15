namespace Juno;


using System;
using System.Diagnostics;
using System.Interop;


[CRepr]
struct Buffer
{
	public ComPtr<ID3D11Buffer> mHandle;
	public ComPtr<ID3D11ShaderResourceView> mSRV;
	public ComPtr<ID3D11UnorderedAccessView> mUAV;
	public CreateInfo mCreateInfo;

	[CRepr]
	public struct CreateInfo
	{
		public Device* mDevice;
		public c_uint mSize;
		public c_uint mStride;
		public Usage mUsage;
		public BindFlags mBindFlags;
		public CpuAccessFlags mCpuAccessFlags;
		public c_bool bStructured;
		public void* mInitialData;
	}
}
