namespace Juno;


using System;
using System.Interop;


[CRepr]
struct Shader
{
	public ShaderStage mStage;
	public ComPtr<ID3D11DeviceChild> mShader;

	[CRepr]
	public struct CompileInfo
	{
		public c_char* mSource;
		public c_size mSourceLength;
		public c_char* mSourceName;
		public c_char* mEntryPoint;
		public c_char* mTarget;
		public ShaderCompileFlags mCompileFlags = .None;
	}

	[CRepr]
	public struct CompileFromFileInfo
	{
		public char16* mPath;
		public c_char* mEntryPoint;
		public c_char* mTarget;
		public ShaderCompileFlags mCompileFlags = .None;
	}

	[CRepr]
	public struct CreateInfo
	{
		public Device* mDevice;
		public ShaderStage mStage;
		public void* mBytecode;
		public c_size mBytecodeSize;
	}
}
