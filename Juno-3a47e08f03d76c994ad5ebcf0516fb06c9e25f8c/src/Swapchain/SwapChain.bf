namespace Juno;


using System;
using System.Diagnostics;
using System.Interop;


[CRepr]
struct SwapChain
{
	public Device* mDevice;
	public HWND mHwnd;
	public ComPtr<IDXGISwapChain1> mSwapChain;
	public ComPtr<IDCompositionDevice> mDCompDevice;
	public ComPtr<IDCompositionTarget> mDCompTarget;
	public ComPtr<IDCompositionVisual> mDCompVisual;
	public Texture mBackBuffer;
	public Texture mDepthBuffer;
	public CreateInfo mDesc;
	public UINT mFlags;
	public bool bTearing;

	[CRepr]
	public struct CreateInfo
	{
		public Device* mDevice = null;
		public void* mWindow = null;
		public c_uint mWidth = 0;
		public c_uint mHeight = 0;
		public PixelFormat mFormat = .B8G8R8A8_UNorm;
		public PixelFormat mDepthFormat = .Unknown;
		public c_uint mBufferCount = 2;
		public c_bool bAllowTearing = false;
		public c_bool bComposition = false;
	}
}
