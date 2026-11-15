namespace Juno;


using System;
using System.Diagnostics;
using System.Interop;


[CRepr]
struct Texture
{
	public ComPtr<ID3D11Texture2D> mTexture;
	public ComPtr<ID3D11ShaderResourceView> mSRV;
	public ComPtr<ID3D11RenderTargetView> mRTV;
	public ComPtr<ID3D11DepthStencilView> mDSV;
	public ComPtr<ID3D11UnorderedAccessView> mUAV;
	public CreateInfo mCreateInfo;
	public c_bool bOwnedBySwapChain;

	[CRepr]
	public struct CreateInfo
	{
		public Device* mDevice;
		public c_uint mWidth = 0;
		public c_uint mHeight = 0;
		public c_uint mMipLevels = 1;
		public c_uint mArraySize = 1;
		public c_uint mSampleCount = 1;
		public PixelFormat mFormat = .R8G8B8A8_UNorm;
		public Usage mUsage = .Default;
		public BindFlags mBindFlags = .ShaderResource;
		public CpuAccessFlags mCpuAccessFlags = default;
		public c_bool bGenerateMips = false;
		public c_bool bCubemap = false;
		public void* mInitialData;
		public c_uint mRowPitch;
	}
}
