namespace Juno;

using System;
using System.IO;
using System.Interop;

// A vertex + pixel shader pair together with the input layout. Switch between programs with
// Graphics.SetShader / PushShader. Source files contain `VSMain` and `PSMain`.
//
// Constant buffer slots used by Graphics (declare them in HLSL to use them):
//   b0 = FrameConstants  { row_major float4x4 gViewProjection; float gTime; float gDeltaTime; float2 gViewportSize; }
//   b1 = ObjectConstants { row_major float4x4 gWorld; float4 gTint; }
//   b2..b7 = user buffers (Graphics.SetConstantBuffer)
// Texture slots t0..t3, sampler s0.
class ShaderProgram
{
	public Shader* mVertexShader;
	public Shader* mPixelShader;
	public InputLayout* mInputLayout;
	public String mName = new .() ~ delete _;

	public ~this()
	{
		if (mInputLayout != null) Juno.DestroyInputLayout(mInputLayout);
		if (mVertexShader != null) Juno.DestroyShader(mVertexShader);
		if (mPixelShader != null) Juno.DestroyShader(mPixelShader);
	}

	static public Result<ShaderProgram> Create(Device* device, StringView source, VertexLayout layout, StringView name = "shader")
	{
		let program = new ShaderProgram();
		program.mName.Set(name);
		if (!program.Build(device, source, layout))
		{
			delete program;
			return .Err;
		}
		return .Ok(program);
	}

	static public Result<ShaderProgram> FromFile(Device* device, StringView path, VertexLayout layout)
	{
		let text = scope String();
		if (File.ReadAllText(path, text) case .Err)
		{
			Console.WriteLine("[Juno] Could not read shader file '{}'", path);
			return .Err;
		}
		return Create(device, text, layout, path);
	}

	bool Build(Device* device, StringView source, VertexLayout layout)
	{
		let nameC = scope String(mName);

		var compileInfo = Shader.CompileInfo()
		{
			mSource = source.Ptr,
			mSourceLength = (c_size)source.Length,
			mSourceName = nameC.CStr(),
			mEntryPoint = "VSMain",
			mTarget = "vs_5_0",
			mCompileFlags = .None
		};
		var result = Juno.CompileShader(&compileInfo, var vsBlob);
		if (!JunoLog.Check(result, scope $"Compile {mName} (VSMain)"))
			return false;

		compileInfo.mEntryPoint = "PSMain";
		compileInfo.mTarget = "ps_5_0";
		result = Juno.CompileShader(&compileInfo, var psBlob);
		if (!JunoLog.Check(result, scope $"Compile {mName} (PSMain)"))
		{
			Juno.DestroyBlob(vsBlob);
			return false;
		}

		var vertexCreateInfo = Shader.CreateInfo()
		{
			mDevice = device,
			mStage = .Vertex,
			mBytecode = Juno.GetBlobData(vsBlob),
			mBytecodeSize = Juno.GetBlobSize(vsBlob)
		};
		result = Juno.CreateShader(&vertexCreateInfo, var vertexShader);
		bool bOk = JunoLog.Check(result, "CreateShader (vertex)");
		if (bOk)
		{
			mVertexShader = vertexShader;

			var pixelCreateInfo = Shader.CreateInfo()
			{
				mDevice = device,
				mStage = .Pixel,
				mBytecode = Juno.GetBlobData(psBlob),
				mBytecodeSize = Juno.GetBlobSize(psBlob)
			};

			result = Juno.CreateShader(&pixelCreateInfo, var pixelShader);
			bOk = JunoLog.Check(result, "CreateShader (pixel)");
			if (bOk)
				mPixelShader = pixelShader;
		}
		if (!bOk)
		{
			Juno.DestroyBlob(vsBlob);
			Juno.DestroyBlob(psBlob);
			return false;
		}

		result = Juno.CreateInputLayout(device, &layout.mElements[0], (c_uint)layout.mElements.Count, Juno.GetBlobData(vsBlob), Juno.GetBlobSize(vsBlob), var inputLayout);
		bOk = JunoLog.Check(result, "CreateInputLayout");
		if (bOk)
			mInputLayout = inputLayout;
		Juno.DestroyBlob(vsBlob);
		Juno.DestroyBlob(psBlob);
		if (!bOk)
			return false;
		return true;
	}
}
