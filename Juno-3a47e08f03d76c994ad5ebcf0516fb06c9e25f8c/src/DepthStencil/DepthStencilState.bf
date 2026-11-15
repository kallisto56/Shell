namespace Juno;


using System;
using System.Diagnostics;
using System.Interop;


[CRepr]
struct DepthStencilState
{
	public ComPtr<ID3D11DepthStencilState> mState;

	[CRepr]
	public struct CreateInfo
	{
		public Device* mDevice;
		public c_bool bDepthEnable = true;
		public c_bool bDepthWriteEnable = true;
		public ComparisonFunc mDepthFunc = .Less;
		public c_bool bStencilEnable = false;
		public c_uchar mStencilReadMask = 0xFF;
		public c_uchar mStencilWriteMask = 0xFF;
		public StencilOpDesc mFrontFace = StencilOpDesc();
		public StencilOpDesc mBackFace = StencilOpDesc();
	}
}
