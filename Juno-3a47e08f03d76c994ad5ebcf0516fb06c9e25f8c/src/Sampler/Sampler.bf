namespace Juno;


using System;
using System.Interop;


[CRepr]
struct Sampler
{
	public ComPtr<ID3D11SamplerState> mState;

	[CRepr]
	public struct CreateInfo
	{
		public Device* mDevice = null;
		public Filter mFilter = .MinMagMipLinear;
		public AddressMode mAddressU = .Clamp;
		public AddressMode mAddressV = .Clamp;
		public AddressMode mAddressW = .Clamp;
		public float mMipLODBias = 0;
		public c_uint mMaxAnisotropy = 1;
		public ComparisonFunc mComparisonFunc = .Never;
		public float mBorderColorR = 0;
		public float mBorderColorG = 0;
		public float mBorderColorB = 0;
		public float mBorderColorA = 0;
		public float mMinLOD = 0;
		public float mMaxLOD = float.MaxValue;
	}
}
