namespace Juno;

using System;
using System.Diagnostics;
using System.Interop;


static class Juno
{
	public function void FatalError(c_char* message, c_char* file, c_int line);

	[AlwaysInclude]
	static public void DefaultFatalError(c_char* message, c_char* file, c_int line)
	{
		var failStr = scope String()..Append(StringView(message), " at line ");
		line.ToString(failStr);
		failStr.Append(" in ", StringView(file));
		Internal.FatalError(failStr, 1);
	}

	[CallingConvention(.Cdecl), LinkName("JunoSetFatalErrorHandler")]
	extern static public ErrorCode SetFatalErrorHandler(FatalError callback);

	[CallingConvention(.Cdecl), LinkName("JunoGetLastErrorMessage")]
	extern static public c_char* GetLastErrorMessage();

	[CallingConvention(.Cdecl), LinkName("JunoGetLastErrorCode")]
	extern static public ErrorCode GetLastErrorCode();

	[CallingConvention(.Cdecl), LinkName("JunoGetLastErrorHResult")]
	extern static public c_int GetLastErrorHResult();

	[CallingConvention(.Cdecl), LinkName("JunoClearLastError")]
	extern static public void ClearLastError();

	[CallingConvention(.Cdecl), LinkName("JunoGetInteropLayoutSizes")]
	extern static public void GetInteropLayoutSizes(InteropLayoutSizes* pSizes);

	static public void ValidateInteropLayout()
	{
		#if DEBUG
		var e = InteropLayoutSizes();
		Juno.GetInteropLayoutSizes(&e);

		var bHasErrors = false;

		void Assert(c_size bfSize, c_size cppSize, String bfName, String cppName)
		{
			if ((uint)bfSize != (uint)cppSize)
			{
				bHasErrors = true;
				Debug.WriteLine(scope $"ERROR: sizeof({bfName}):{bfSize} and sizeof({cppName}):{cppSize} do not match");
			}
		}

		Assert(sizeof(Device.CreateInfo), e.mJunoDeviceCreateInfo, "Device.CreateInfo", "JunoDeviceCreateInfo");
		Assert(sizeof(Shader.CreateInfo), e.mJunoShaderCreateInfo, "Shader.CreateInfo", "JunoShaderCreateInfo");
		Assert(sizeof(Shader.CompileFromFileInfo), e.mJunoShaderCompileFromFileInfo, "Shader.CompileFromFileInfo", "JunoShaderCompileFromFileInfo");
		Assert(sizeof(Shader.CompileInfo), e.mJunoShaderCompileInfo, "Shader.CompileInfo", "JunoShaderCompileInfo");
		Assert(sizeof(SwapChain.CreateInfo), e.mJunoSwapChainCreateInfo, "SwapChain.CreateInfo", "JunoSwapChainCreateInfo");
		Assert(sizeof(Buffer.CreateInfo), e.mJunoBufferCreateInfo, "Buffer.CreateInfo", "JunoBufferCreateInfo");
		Assert(sizeof(Texture.CreateInfo), e.mJunoTextureCreateInfo, "Texture.CreateInfo", "JunoTextureCreateInfo");
		Assert(sizeof(Region), e.mJunoRegion, "Region", "JunoRegion");
		Assert(sizeof(Viewport), e.mJunoViewport, "Viewport", "JunoViewport");
		Assert(sizeof(Scissor), e.mJunoScissor, "Scissor", "JunoScissor");
		Assert(sizeof(Sampler.CreateInfo), e.mJunoSamplerCreateInfo, "Sampler.CreateInfo", "JunoSamplerCreateInfo");
		Assert(sizeof(InputElementDescription), e.mJunoInputElementDescription, "InputElementDescription", "JunoInputElementDescription");
		Assert(sizeof(BlendDesc), e.mJunoBlendDesc, "BlendDesc", "JunoBlendDesc");
		Assert(sizeof(RasterizerDesc), e.mJunoRasterizerDesc, "RasterizerDesc", "JunoRasterizerDesc");
		Assert(sizeof(StencilOpDesc), e.mJunoStencilOpDesc, "StencilOpDesc", "JunoStencilOpDesc");
		Assert(sizeof(DepthStencilState.CreateInfo), e.mJunoDepthStencilCreateInfo, "DepthStencilState.CreateInfo", "JunoDepthStencilCreateInfo");

		Assert(sizeof(InteropLayoutSizes), e.mJunoInteropLayoutSizes, "InteropLayoutSizes", "JunoInteropLayoutSizes");

		if (bHasErrors) Runtime.FatalError();
		#endif
	}

	[CallingConvention(.Cdecl), LinkName("JunoCreateDevice")]
	extern static public ErrorCode CreateDevice(Device.CreateInfo* pCreateInfo, out Device* ppDevice);

	[CallingConvention(.Cdecl), LinkName("JunoDestroyDevice")]
	extern static public void DestroyDevice(Device* pDevice);

	[CallingConvention(.Cdecl), LinkName("JunoFlush")]
	extern static public void Flush(Device* pDevice);

	[CallingConvention(.Cdecl), LinkName("JunoClearState")]
	extern static public void ClearState(Device* pDevice);

	[CallingConvention(.Cdecl), LinkName("JunoCreateSwapChain")]
	extern static public ErrorCode CreateSwapChain(SwapChain.CreateInfo* pCreateInfo, out SwapChain* ppSwapChain);

	[CallingConvention(.Cdecl), LinkName("JunoDestroySwapChain")]
	extern static public void DestroySwapChain(SwapChain* pSwapChain);

	[CallingConvention(.Cdecl), LinkName("JunoResizeSwapChain")]
	extern static public ErrorCode ResizeSwapChain(SwapChain* pSwapChain, c_uint width, c_uint height);

	[CallingConvention(.Cdecl), LinkName("JunoPresent")]
	extern static public ErrorCode Present(SwapChain* pSwapChain, c_bool bVSync);

	[CallingConvention(.Cdecl), LinkName("JunoGetBackBuffer")]
	extern static public Texture* GetBackBuffer(SwapChain* pSwapChain);

	[CallingConvention(.Cdecl), LinkName("JunoGetDepthBuffer")]
	extern static public Texture* GetDepthBuffer(SwapChain* pSwapChain);

	[CallingConvention(.Cdecl), LinkName("JunoCreateBuffer")]
	extern static public ErrorCode CreateBuffer(Buffer.CreateInfo* pCreateInfo, out Buffer* ppBuffer);

	[CallingConvention(.Cdecl), LinkName("JunoDestroyBuffer")]
	extern static public void DestroyBuffer(Buffer* pBuffer);

	[CallingConvention(.Cdecl), LinkName("JunoUpdateBuffer")]
	extern static public ErrorCode UpdateBuffer(Device* pDevice, Buffer* pBuffer, c_size offset, void* pData, c_size size);

	[CallingConvention(.Cdecl), LinkName("JunoMapBuffer")]
	extern static public ErrorCode MapBuffer(Device* pDevice, Buffer* pBuffer, MapMode mode, out void* ppData);

	[CallingConvention(.Cdecl), LinkName("JunoUnmapBuffer")]
	extern static public void UnmapBuffer(Device* pDevice, Buffer* pBuffer);

	[CallingConvention(.Cdecl), LinkName("JunoCopyBuffer")]
	extern static public void CopyBuffer(Device* pDevice, Buffer* pDst, Buffer* pSrc);

	[CallingConvention(.Cdecl), LinkName("JunoSetVertexBuffers")]
	extern static public void SetVertexBuffers(Device* pDevice, c_uint startSlot, c_uint count, Buffer** ppBuffers, c_uint* pStrides, c_uint* pOffsets);

	[CallingConvention(.Cdecl), LinkName("JunoSetIndexBuffer")]
	extern static public void SetIndexBuffer(Device* pDevice, Buffer* pBuffer, IndexFormat format, c_uint offset);

	[CallingConvention(.Cdecl), LinkName("JunoSetConstantBuffers")]
	extern static public void SetConstantBuffers(Device* pDevice, ShaderStage stage, c_uint startSlot, c_uint count, Buffer** ppBuffers);

	[CallingConvention(.Cdecl), LinkName("JunoSetBufferResources")]
	extern static public void SetBufferResources(Device* pDevice, ShaderStage stage, c_uint startSlot, c_uint count, Buffer** ppBuffers);

	[CallingConvention(.Cdecl), LinkName("JunoSetUnorderedAccessBuffers")]
	extern static public void SetUnorderedAccessBuffers(Device* pDevice, c_uint startSlot, c_uint count, Buffer** ppBuffers);

	[CallingConvention(.Cdecl), LinkName("JunoCreateTexture")]
	extern static public ErrorCode CreateTexture(Texture.CreateInfo* pCreateInfo, out Texture* ppTexture);

	[CallingConvention(.Cdecl), LinkName("JunoDestroyTexture")]
	extern static public void DestroyTexture(Texture* pTexture);

	[CallingConvention(.Cdecl), LinkName("JunoUpdateTexture")]
	extern static public ErrorCode UpdateTexture(Device* pDevice, Texture* pTexture, c_uint arraySlice, c_uint mipLevel, Region* pRegion, void* pData, c_uint rowPitch);

	[CallingConvention(.Cdecl), LinkName("JunoMapTexture")]
	extern static public ErrorCode MapTexture(Device* pDevice, Texture* pTexture, c_uint arraySlice, c_uint mipLevel, MapMode mode, out void* ppData, c_uint* pRowPitch);

	[CallingConvention(.Cdecl), LinkName("JunoUnmapTexture")]
	extern static public void UnmapTexture(Device* pDevice, Texture* pTexture, c_uint arraySlice, c_uint mipLevel);

	[CallingConvention(.Cdecl), LinkName("JunoGenerateMips")]
	extern static public void GenerateMips(Device* pDevice, Texture* pTexture);

	[CallingConvention(.Cdecl), LinkName("JunoCopyTexture")]
	extern static public void CopyTexture(Device* pDevice, Texture* pDst, Texture* pSrc);

	[CallingConvention(.Cdecl), LinkName("JunoResolveTexture")]
	extern static public void ResolveTexture(Device* pDevice, Texture* pDst, Texture* pSrc);

	[CallingConvention(.Cdecl), LinkName("JunoGetTextureSize")]
	extern static public void GetTextureSize(Texture* pTexture, c_uint* pWidth, c_uint* pHeight);

	[CallingConvention(.Cdecl), LinkName("JunoClearRenderTarget")]
	extern static public void ClearRenderTarget(Device* pDevice, Texture* pTexture, float r, float g, float b, float a);

	[CallingConvention(.Cdecl), LinkName("JunoClearDepthStencil")]
	extern static public void ClearDepthStencil(Device* pDevice, Texture* pTexture, ClearFlags clearFlags, float depth, c_uchar stencil);

	[CallingConvention(.Cdecl), LinkName("JunoSetTextures")]
	extern static public void SetTextures(Device* pDevice, ShaderStage stage, c_uint startSlot, c_uint count, Texture** ppTextures);

	[CallingConvention(.Cdecl), LinkName("JunoSetUnorderedAccessTextures")]
	extern static public void SetUnorderedAccessTextures(Device* pDevice, c_uint startSlot, c_uint count, Texture** ppTextures);

	[CallingConvention(.Cdecl), LinkName("JunoLoadImage")]
	extern static public ErrorCode LoadImage(void* pData, c_size size, PixelFormat desiredFormat, out JunoImage* ppImage);

	[CallingConvention(.Cdecl), LinkName("JunoDestroyImage")]
	extern static public void DestroyImage(JunoImage* pImage);

	[CallingConvention(.Cdecl), LinkName("JunoCreateTextureFromImage")]
	extern static public ErrorCode CreateTextureFromImage(Device* pDevice, JunoImage* pImage, c_bool bGenerateMips, out Texture* ppTexture);

	[CallingConvention(.Cdecl), LinkName("JunoCreateSampler")]
	extern static public ErrorCode CreateSampler(Sampler.CreateInfo* pCreateInfo, out Sampler* ppSampler);

	[CallingConvention(.Cdecl), LinkName("JunoDestroySampler")]
	extern static public void DestroySampler(Sampler* pSampler);

	[CallingConvention(.Cdecl), LinkName("JunoSetSamplers")]
	extern static public void SetSamplers(Device* pDevice, ShaderStage stage, c_uint startSlot, c_uint count, Sampler** ppSamplers);

	[CallingConvention(.Cdecl), LinkName("JunoCompileShader")]
	extern static public ErrorCode CompileShader(Shader.CompileInfo* pCompileInfo, out Blob* ppBlob);

	[CallingConvention(.Cdecl), LinkName("JunoCompileShaderFromFile")]
	extern static public ErrorCode CompileShaderFromFile(Shader.CompileFromFileInfo* pCompileInfo, out Blob* ppBlob);

	[CallingConvention(.Cdecl), LinkName("JunoGetBlobData")]
	extern static public void* GetBlobData(Blob* pBlob);

	[CallingConvention(.Cdecl), LinkName("JunoGetBlobSize")]
	extern static public c_size GetBlobSize(Blob* pBlob);

	[CallingConvention(.Cdecl), LinkName("JunoDestroyBlob")]
	extern static public void DestroyBlob(Blob* pBlob);

	[CallingConvention(.Cdecl), LinkName("JunoCreateShader")]
	extern static public ErrorCode CreateShader(Shader.CreateInfo* pCreateInfo, out Shader* ppShader);

	[CallingConvention(.Cdecl), LinkName("JunoDestroyShader")]
	extern static public void DestroyShader(Shader* pShader);

	[CallingConvention(.Cdecl), LinkName("JunoSetShader")]
	extern static public void SetShader(Device* pDevice, Shader* pShader);

	[CallingConvention(.Cdecl), LinkName("JunoUnsetShader")]
	extern static public void UnsetShader(Device* pDevice, ShaderStage stage);

	[CallingConvention(.Cdecl), LinkName("JunoCreateInputLayout")]
	extern static public ErrorCode CreateInputLayout(Device* pDevice, InputElementDescription* pElements, c_uint elementCount, void* pVertexShaderBytecode, c_size vertexShaderBytecodeSize, out InputLayout* ppLayout);

	[CallingConvention(.Cdecl), LinkName("JunoDestroyInputLayout")]
	extern static public void DestroyInputLayout(InputLayout* pLayout);

	[CallingConvention(.Cdecl), LinkName("JunoSetInputLayout")]
	extern static public void SetInputLayout(Device* pDevice, InputLayout* pLayout);

	[CallingConvention(.Cdecl), LinkName("JunoCreateBlendState")]
	extern static public ErrorCode CreateBlendState(Device* pDevice, BlendDesc* pDesc, out BlendState* ppState);

	[CallingConvention(.Cdecl), LinkName("JunoDestroyBlendState")]
	extern static public void DestroyBlendState(BlendState* pState);

	[CallingConvention(.Cdecl), LinkName("JunoSetBlendState")]
	extern static public void SetBlendState(Device* pDevice, BlendState* pState, float* pBlendFactor, c_uint sampleMask);

	[CallingConvention(.Cdecl), LinkName("JunoCreateRasterizerState")]
	extern static public ErrorCode CreateRasterizerState(Device* pDevice, RasterizerDesc* pDesc, out RasterizerState* ppState);

	[CallingConvention(.Cdecl), LinkName("JunoDestroyRasterizerState")]
	extern static public void DestroyRasterizerState(RasterizerState* pState);

	[CallingConvention(.Cdecl), LinkName("JunoSetRasterizerState")]
	extern static public void SetRasterizerState(Device* pDevice, RasterizerState* pState);

	[CallingConvention(.Cdecl), LinkName("JunoCreateDepthStencilState")]
	extern static public ErrorCode CreateDepthStencilState(DepthStencilState.CreateInfo* pCreateInfo, out DepthStencilState* ppState);

	[CallingConvention(.Cdecl), LinkName("JunoDestroyDepthStencilState")]
	extern static public void DestroyDepthStencilState(DepthStencilState* pState);

	[CallingConvention(.Cdecl), LinkName("JunoSetDepthStencilState")]
	extern static public void SetDepthStencilState(Device* pDevice, DepthStencilState* pState, c_uint stencilRef);

	[CallingConvention(.Cdecl), LinkName("JunoSetRenderTargets")]
	extern static public void SetRenderTargets(Device* pDevice, c_uint count, Texture** ppColorTargets, Texture* pDepthTarget);

	[CallingConvention(.Cdecl), LinkName("JunoSetViewports")]
	extern static public void SetViewports(Device* pDevice, c_uint count, Viewport* pViewports);

	[CallingConvention(.Cdecl), LinkName("JunoSetScissorRects")]
	extern static public void SetScissorRects(Device* pDevice, Scissor* pScissors, c_uint count);

	[CallingConvention(.Cdecl), LinkName("JunoSetPrimitiveTopology")]
	extern static public void SetPrimitiveTopology(Device* pDevice, PrimitiveTopology topology);

	[CallingConvention(.Cdecl), LinkName("JunoDraw")]
	extern static public void Draw(Device* pDevice, c_uint vertexCount, c_uint startVertex);

	[CallingConvention(.Cdecl), LinkName("JunoDrawIndexed")]
	extern static public void DrawIndexed(Device* pDevice, c_uint indexCount, c_uint startIndex, c_int baseVertex);

	[CallingConvention(.Cdecl), LinkName("JunoDrawInstanced")]
	extern static public void DrawInstanced(Device* pDevice, c_uint vertexCountPerInstance, c_uint instanceCount, c_uint startVertex, c_uint startInstance);

	[CallingConvention(.Cdecl), LinkName("JunoDrawIndexedInstanced")]
	extern static public void DrawIndexedInstanced(Device* pDevice, c_uint indexCountPerInstance, c_uint instanceCount, c_uint startIndex, c_int baseVertex, c_uint startInstance);

	[CallingConvention(.Cdecl), LinkName("JunoDispatch")]
	extern static public void Dispatch(Device* pDevice, c_uint groupsX, c_uint groupsY, c_uint groupsZ);

	[CallingConvention(.Cdecl), LinkName("JunoCreateFence")]
	extern static public ErrorCode CreateFence(Device* pDevice, out Fence* ppFence);

	[CallingConvention(.Cdecl), LinkName("JunoDestroyFence")]
	extern static public void DestroyFence(Fence* pFence);

	[CallingConvention(.Cdecl), LinkName("JunoInsertFence")]
	extern static public void InsertFence(Device* pDevice, Fence* pFence);

	[CallingConvention(.Cdecl), LinkName("JunoIsFenceSignaled")]
	extern static public c_bool IsFenceSignaled(Device* pDevice, Fence* pFence);

	[CallingConvention(.Cdecl), LinkName("JunoWaitFence")]
	extern static public void WaitFence(Device* pDevice, Fence* pFence);
}
