namespace Juno;

using System;
using System.Collections;
using System.Interop;

// Immediate-mode + retained rendering on top of Juno.
//
//   Immediate   : FillRect / DrawLine / DrawTexture / DrawString ... append quads to a dynamic vertex+index buffer
//                 (PushBuffer). The batch is submitted automatically when state changes (texture, shader, blend,
//                 clip, target, camera ...) or when the buffer is full, and at EndFrame().
//   Retained    : DrawMesh(mesh, world, texture, tint) draws a static Mesh (own GPU buffers) right away.
//   Shaders     : SetShader / PushShader switch the active ShaderProgram (null = built-in default). Any number of
//                 programs can be used in one frame (3D scene, UI, post-processing ...).
//   Targets     : SetRenderTarget / PushRenderTarget render into a RenderTarget; null = back buffer.
//   Text        : DrawString(font, ...) uses HarfBuzz shaping and glyph atlas pages (see Font).
//
// 2D coordinates: pixels, origin top-left, Y down (default projection). 2D transform/tint/clip stacks are applied
// on the CPU while vertices are pushed. For 3D use SetCamera(view, projection) + DrawMesh / DrawVertices.
class Graphics
{
	public const uint32 cMaxVertices = 65536;
	public const uint32 cMaxIndices = 196608;
	public const int cTextureSlots = 4;
	public const int cUserConstantBuffers = 6;      // slots b2..b7

	[CRepr]
	struct FrameConstants
	{
		public Matrix4x4 mViewProjection;
		public float mTime;
		public float mDeltaTime;
		public float mViewportWidth;
		public float mViewportHeight;
	}

	[CRepr]
	struct ObjectConstants
	{
		public Matrix4x4 mWorld;
		public float mTintR;
		public float mTintG;
		public float mTintB;
		public float mTintA;
	}

	struct ClipState
	{
		public Rect mRect;      // device pixels
		public bool bEnabled;
	}

	const String cDefaultShaderSource = @"""
cbuffer FrameConstants : register(b0)
{
	row_major float4x4 gViewProjection;
	float gTime;
	float gDeltaTime;
	float2 gViewportSize;
};

cbuffer ObjectConstants : register(b1)
{
	row_major float4x4 gWorld;
	float4 gTint;
};

Texture2D gTexture : register(t0);
SamplerState gSampler : register(s0);

struct VSInput
{
	float3 position : POSITION;
	float2 uv       : TEXCOORD;
	float4 color    : COLOR;
};

struct PSInput
{
	float4 position : SV_POSITION;
	float2 uv       : TEXCOORD;
	float4 color    : COLOR;
};

PSInput VSMain(VSInput input)
{
	PSInput output;
	output.position = mul(mul(float4(input.position, 1.0f), gWorld), gViewProjection);
	output.uv = input.uv;
	output.color = input.color * gTint;
	return output;
}

float4 PSMain(PSInput input) : SV_TARGET
{
	return gTexture.Sample(gSampler, input.uv) * input.color;
}
""";

	public Device* mDevice;
	public VertexLayout mVertexLayout ~ delete _;
	public ShaderProgram mDefaultShader ~ delete _;
	public Texture2D mWhiteTexture ~ delete _;
	public TextLayout mTextLayout = new .() ~ delete _;

	// GPU objects
	Buffer* mDynamicVB;
	Buffer* mDynamicIB;
	Buffer* mFrameCB;
	Buffer* mObjectCB;
	Sampler*[4] mSamplers;
	BlendState*[4] mBlendStates;
	DepthStencilState*[3] mDepthStates;
	RasterizerState*[12] mRasterizerStates;

	// Dynamic geometry
	PushBuffer mVertices;
	PushBuffer mIndices;
	uint32 mBatchIndexStart;
	uint32 mBatchIndexCount;

	// Current target
	SwapChain* mSwapChain;
	Texture* mBackBuffer;
	Texture* mBackDepth;
	RenderTarget mRenderTarget;
	List<RenderTarget> mRenderTargetStack = new .() ~ delete _;
	public int32 mTargetWidth;
	public int32 mTargetHeight;

	// Pipeline state
	ShaderProgram mShader;
	List<ShaderProgram> mShaderStack = new .() ~ delete _;
	Texture2D[4] mTextures;
	ConstantBuffer[6] mUserConstantBuffers;
	BlendMode mBlendMode = .Alpha;
	DepthMode mDepthMode = .None;
	CullMode mCullMode = .None;
	SamplerKind mSamplerKind = .LinearClamp;
	bool bWireframe;

	// Camera / constants
	Matrix4x4 mViewProjection = Matrix4x4.sIdentity;
	Matrix4x4 mWorld = Matrix4x4.sIdentity;
	Color mObjectTint = Color.cWhite;
	bool bCustomProjection;
	bool bConstantsDirty = true;

	// 2D stacks
	float mM11 = 1, mM12 = 0, mM21 = 0, mM22 = 1, mM31 = 0, mM32 = 0;
	Matrix3x2 mTransform = Matrix3x2.sIdentity;
	List<Matrix3x2> mTransformStack = new .() ~ delete _;
	Color mTint = Color.cWhite;
	List<Color> mTintStack = new .() ~ delete _;
	ClipState mClip;
	List<ClipState> mClipStack = new .() ~ delete _;

	// Frame data
	bool bFrameActive;
	public float mTime;
	public float mDeltaTime;
	public int32 mDrawCalls;
	public int32 mVerticesPushed;

	public ~this()
	{
		if (mDynamicVB != null) Juno.DestroyBuffer(mDynamicVB);
		if (mDynamicIB != null) Juno.DestroyBuffer(mDynamicIB);
		if (mFrameCB != null) Juno.DestroyBuffer(mFrameCB);
		if (mObjectCB != null) Juno.DestroyBuffer(mObjectCB);
		for (int i < 4) if (mSamplers[i] != null) Juno.DestroySampler(mSamplers[i]);
		for (int i < 4) if (mBlendStates[i] != null) Juno.DestroyBlendState(mBlendStates[i]);
		for (int i < 3) if (mDepthStates[i] != null) Juno.DestroyDepthStencilState(mDepthStates[i]);
		for (int i < 12) if (mRasterizerStates[i] != null) Juno.DestroyRasterizerState(mRasterizerStates[i]);
	}

	// ---------------------------------------------------------------------------------------------------------
	// Setup
	// ---------------------------------------------------------------------------------------------------------

	public bool Initialize(Device* device)
	{
		mDevice = device;
		mVertexLayout = Vertex.CreateLayout();

		// Dynamic geometry buffers
		Buffer.CreateInfo info = default;
		info.mDevice = device;
		info.mUsage = .Dynamic;
		info.mCpuAccessFlags = .Write;
		info.mSize = cMaxVertices * sizeof(Vertex);
		info.mStride = sizeof(Vertex);
		info.mBindFlags = .VertexBuffer;
		if (!JunoLog.Check(Juno.CreateBuffer(&info, var vb), "CreateBuffer (dynamic vertices)"))
			return false;
		mDynamicVB = vb;

		info.mSize = cMaxIndices * (c_uint)sizeof(uint32);
		info.mStride = (c_uint)sizeof(uint32);
		info.mBindFlags = .IndexBuffer;
		if (!JunoLog.Check(Juno.CreateBuffer(&info, var ib), "CreateBuffer (dynamic indices)"))
			return false;
		mDynamicIB = ib;

		// Constant buffers
		info = default;
		info.mDevice = device;
		info.mUsage = .Default;
		info.mBindFlags = .ConstantBuffer;
		info.mSize = (c_uint)sizeof(FrameConstants);
		if (!JunoLog.Check(Juno.CreateBuffer(&info, var fcb), "CreateBuffer (frame constants)"))
			return false;
		mFrameCB = fcb;

		info.mSize = (c_uint)sizeof(ObjectConstants);
		if (!JunoLog.Check(Juno.CreateBuffer(&info, var ocb), "CreateBuffer (object constants)"))
			return false;
		mObjectCB = ocb;

		mVertices = PushBuffer(device, mDynamicVB, cMaxVertices);
		mIndices = PushBuffer(device, mDynamicIB, cMaxIndices);

		if (!CreateStates())
			return false;

		// 1x1 white texture: lets untextured geometry use the same shader.
		uint8[4] white = .(255, 255, 255, 255);
		if (Texture2D.Create(device, 1, 1, .R8G8B8A8_UNorm, &white[0], 4) case .Ok(let tex))
			mWhiteTexture = tex;
		else
			return false;

		if (ShaderProgram.Create(device, cDefaultShaderSource, mVertexLayout, "DefaultShader") case .Ok(let program))
			mDefaultShader = program;
		else
			return false;

		return true;
	}

	bool CreateStates()
	{
		// Blend
		for (int i < BlendMode.cCount)
		{
			BlendDesc bd = .();
			switch ((BlendMode)i)
			{
			case .Opaque:
			case .Alpha:
				bd.bBlendEnable = true;
				bd.mSrcBlend = .SrcAlpha; bd.mDestBlend = .InvSrcAlpha;
				bd.mSrcBlendAlpha = .One; bd.mDestBlendAlpha = .InvSrcAlpha;
			case .Additive:
				bd.bBlendEnable = true;
				bd.mSrcBlend = .SrcAlpha; bd.mDestBlend = .One;
				bd.mSrcBlendAlpha = .One; bd.mDestBlendAlpha = .One;
			case .Premultiplied:
				bd.bBlendEnable = true;
				bd.mSrcBlend = .One; bd.mDestBlend = .InvSrcAlpha;
				bd.mSrcBlendAlpha = .One; bd.mDestBlendAlpha = .InvSrcAlpha;
			}
			if (!JunoLog.Check(Juno.CreateBlendState(mDevice, &bd, var state), "CreateBlendState"))
				return false;
			mBlendStates[i] = state;
		}

		// Depth
		for (int i < DepthMode.cCount)
		{
			DepthStencilState.CreateInfo dd = .();
			dd.mDevice = mDevice;
			switch ((DepthMode)i)
			{
			case .None:
				dd.bDepthEnable = false;
				dd.bDepthWriteEnable = false;
			case .ReadWrite:
				dd.bDepthEnable = true;
				dd.bDepthWriteEnable = true;
				dd.mDepthFunc = .LessEqual;
			case .ReadOnly:
				dd.bDepthEnable = true;
				dd.bDepthWriteEnable = false;
				dd.mDepthFunc = .LessEqual;
			}
			if (!JunoLog.Check(Juno.CreateDepthStencilState(&dd, var state), "CreateDepthStencilState"))
				return false;
			mDepthStates[i] = state;
		}

		// Samplers
		for (int i < SamplerKind.cCount)
		{
			Sampler.CreateInfo sd = .();
			sd.mDevice = mDevice;
			let kind = (SamplerKind)i;
			let bPoint = (kind == .PointClamp || kind == .PointWrap);
			let bWrap = (kind == .PointWrap || kind == .LinearWrap);
			sd.mFilter = bPoint ? .MinMagMipPoint : .MinMagMipLinear;
			sd.mAddressU = bWrap ? .Wrap : .Clamp;
			sd.mAddressV = sd.mAddressU;
			sd.mAddressW = sd.mAddressU;
			if (!JunoLog.Check(Juno.CreateSampler(&sd, var state), "CreateSampler"))
				return false;
			mSamplers[i] = state;
		}
		return true;
	}

	// Rasterizer states are created on demand: cull (3) x wireframe (2) x scissor (2).
	RasterizerState* GetRasterizerState(CullMode cull, bool wire, bool scissor)
	{
		let index = (((int)cull - 1) * 2 + (wire ? 1 : 0)) * 2 + (scissor ? 1 : 0);
		if (mRasterizerStates[index] == null)
		{
			RasterizerDesc rd = .();
			rd.mCullMode = cull;
			rd.mFillMode = wire ? .Wireframe : .Solid;
			rd.bScissorEnable = scissor;
			JunoLog.Check(Juno.CreateRasterizerState(mDevice, &rd, var state), "CreateRasterizerState");
			mRasterizerStates[index] = state;
		}
		return mRasterizerStates[index];
	}

	// ---------------------------------------------------------------------------------------------------------
	// Frame
	// ---------------------------------------------------------------------------------------------------------

	// Called by Application. Binds the back buffer (+ depth) and resets all state.
	public void BeginFrame(SwapChain* swapChain, float time, float deltaTime)
	{
		mSwapChain = swapChain;
		mBackBuffer = Juno.GetBackBuffer(swapChain);
		mBackDepth = Juno.GetDepthBuffer(swapChain);
		mTime = time;
		mDeltaTime = deltaTime;
		mDrawCalls = 0;
		mVerticesPushed = 0;

		mVertices.Reset();
		mIndices.Reset();
		mBatchIndexStart = 0;
		mBatchIndexCount = 0;
		mVertices.Map(.WriteDiscard);
		mIndices.Map(.WriteDiscard);
		bFrameActive = true;

		mRenderTarget = null;
		mRenderTargetStack.Clear();
		ResetState();
	}

	// Submits everything that is still batched and unmaps the dynamic buffers.
	public void EndFrame()
	{
		Flush();
		mVertices.Unmap();
		mIndices.Unmap();
		bFrameActive = false;
	}

	// Back to defaults: default shader, alpha blending, no depth, no culling, identity transform, white tint,
	// no clip, pixel-space projection, back buffer as target.
	public void ResetState()
	{
		Flush();
		mShader = null;
		mShaderStack.Clear();
		for (int i < cTextureSlots) mTextures[i] = null;
		mTextures[0] = mWhiteTexture;
		for (int i < cUserConstantBuffers) mUserConstantBuffers[i] = null;
		mBlendMode = .Alpha;
		mDepthMode = .None;
		mCullMode = .None;
		mSamplerKind = .LinearClamp;
		bWireframe = false;
		mWorld = Matrix4x4.sIdentity;
		mObjectTint = Color.cWhite;
		bCustomProjection = false;
		bConstantsDirty = true;

		mTransformStack.Clear();
		SetTransformInternal(Matrix3x2.sIdentity);
		mTintStack.Clear();
		mTint = Color.cWhite;
		mClipStack.Clear();
		mClip = default;

		mRenderTarget = null;
		mRenderTargetStack.Clear();
		ApplyRenderTarget();
	}

	public void Clear(Color color)
	{
		Flush();
		Texture* target = (mRenderTarget != null) ? mRenderTarget.mColor.mHandle : mBackBuffer;
		Juno.ClearRenderTarget(mDevice, target,
			(float)color.mR / 255.0f, (float)color.mG / 255.0f, (float)color.mB / 255.0f, (float)color.mA / 255.0f);
	}

	public void ClearDepth(float depth = 1.0f)
	{
		Flush();
		Texture* target = mBackDepth;
		if (mRenderTarget != null)
			target = (mRenderTarget.mDepth != null) ? mRenderTarget.mDepth.mHandle : null;
		if (target != null)
			Juno.ClearDepthStencil(mDevice, target, .Depth | .Stencil, depth, 0);
	}

	// ---------------------------------------------------------------------------------------------------------
	// Render targets
	// ---------------------------------------------------------------------------------------------------------

	// null = back buffer.
	public void SetRenderTarget(RenderTarget target)
	{
		Flush();
		mRenderTarget = target;
		ApplyRenderTarget();
	}

	public GraphicsScope PushRenderTarget(RenderTarget target)
	{
		mRenderTargetStack.Add(mRenderTarget);
		SetRenderTarget(target);
		return GraphicsScope(this, .RenderTarget);
	}

	public void PopRenderTarget()
	{
		if (mRenderTargetStack.Count == 0)
			return;
		let previous = mRenderTargetStack.PopBack();
		SetRenderTarget(previous);
	}

	void ApplyRenderTarget()
	{
		Texture* color = mBackBuffer;
		Texture* depth = mBackDepth;
		if (mRenderTarget != null)
		{
			color = mRenderTarget.mColor.mHandle;
			depth = (mRenderTarget.mDepth != null) ? mRenderTarget.mDepth.mHandle : null;
			mTargetWidth = mRenderTarget.mWidth;
			mTargetHeight = mRenderTarget.mHeight;
		}
		else
		{
			var w = c_uint(0);
			var h = c_uint(0);
			Juno.GetTextureSize(mBackBuffer, &w, &h);
			mTargetWidth = (int32)w;
			mTargetHeight = (int32)h;
		}

		// A texture must not be bound for sampling while it is a render target.
		Texture*[4] nothing = default;
		Juno.SetTextures(mDevice, .Pixel, 0, 4, &nothing[0]);
		Juno.SetRenderTargets(mDevice, 1, &color, depth);

		Viewport viewport = .();
		viewport.mWidth = (float)mTargetWidth;
		viewport.mHeight = (float)mTargetHeight;
		Juno.SetViewports(mDevice, 1, &viewport);

		if (!bCustomProjection)
			UpdateDefaultProjection();
	}

	// ---------------------------------------------------------------------------------------------------------
	// Camera
	// ---------------------------------------------------------------------------------------------------------

	void UpdateDefaultProjection()
	{
		let w = (float)mTargetWidth;
		let h = (float)mTargetHeight;
		mViewProjection = Matrix4x4(
			2.0f / w, 0, 0, 0,
			0, -2.0f / h, 0, 0,
			0, 0, 1, 0,
			-1, 1, 0, 1);
		bConstantsDirty = true;
	}

	// Replaces the default pixel-space projection. Row-vector convention: position * view * projection.
	public void SetCamera(Matrix4x4 view, Matrix4x4 projection)
	{
		Flush();
		mViewProjection = view * projection;
		bCustomProjection = true;
		bConstantsDirty = true;
	}

	public void SetViewProjection(Matrix4x4 viewProjection)
	{
		Flush();
		mViewProjection = viewProjection;
		bCustomProjection = true;
		bConstantsDirty = true;
	}

	// Back to pixel coordinates (origin top-left) of the current target.
	public void ResetCamera()
	{
		Flush();
		bCustomProjection = false;
		UpdateDefaultProjection();
	}

	// ---------------------------------------------------------------------------------------------------------
	// Pipeline state (each setter flushes the current batch if the value changes)
	// ---------------------------------------------------------------------------------------------------------

	public void SetShader(ShaderProgram shader)
	{
		if (mShader == shader)
			return;
		Flush();
		mShader = shader;
	}

	public GraphicsScope PushShader(ShaderProgram shader)
	{
		mShaderStack.Add(mShader);
		SetShader(shader);
		return GraphicsScope(this, .Shader);
	}

	public void PopShader()
	{
		if (mShaderStack.Count == 0)
			return;
		SetShader(mShaderStack.PopBack());
	}

	public void SetBlendMode(BlendMode mode)
	{
		if (mBlendMode == mode) return;
		Flush();
		mBlendMode = mode;
	}

	public void SetDepthMode(DepthMode mode)
	{
		if (mDepthMode == mode) return;
		Flush();
		mDepthMode = mode;
	}

	public void SetCullMode(CullMode mode)
	{
		if (mCullMode == mode) return;
		Flush();
		mCullMode = mode;
	}

	public void SetWireframe(bool enable)
	{
		if (bWireframe == enable) return;
		Flush();
		bWireframe = enable;
	}

	public void SetSampler(SamplerKind kind)
	{
		if (mSamplerKind == kind) return;
		Flush();
		mSamplerKind = kind;
	}

	// slot 0 is what the default shader samples. null = white texture (slot 0) / unbound (others).
	public void SetTexture(Texture2D texture, int slot = 0)
	{
		Texture2D value = texture;
		if (slot == 0 && value == null)
			value = mWhiteTexture;
		if (mTextures[slot] == value)
			return;
		Flush();
		mTextures[slot] = value;
	}

	// Binds a user constant buffer to slot b(2 + index) of the vertex and pixel stage. Index 0..5.
	public void SetConstantBuffer(int index, ConstantBuffer buffer)
	{
		if (mUserConstantBuffers[index] == buffer)
			return;
		Flush();
		mUserConstantBuffers[index] = buffer;
	}

	// ---------------------------------------------------------------------------------------------------------
	// 2D state stacks
	// ---------------------------------------------------------------------------------------------------------

	void SetTransformInternal(Matrix3x2 m)
	{
		mTransform = m;
		mM11 = m.m11; mM12 = m.m12;
		mM21 = m.m21; mM22 = m.m22;
		mM31 = m.m31; mM32 = m.m32;
	}

	public GraphicsScope PushTransform(Matrix3x2 matrix)
	{
		mTransformStack.Add(mTransform);
		SetTransformInternal(matrix * mTransform);      // local first, then the parent transform
		return GraphicsScope(this, .Transform);
	}

	public GraphicsScope PushTranslate(float x, float y)
	{
		return PushTransform(Matrix3x2.CreateTranslation(Vector2(x, y)));
	}

	public GraphicsScope PushScale(float x, float y)
	{
		return PushTransform(Matrix3x2.CreateScale(Vector2(x, y)));
	}

	public GraphicsScope PushRotate(float radians, float centerX = 0, float centerY = 0)
	{
		return PushTransform(Matrix3x2.CreateRotation(radians, Vector2(centerX, centerY)));
	}

	public void PopTransform()
	{
		if (mTransformStack.Count == 0)
			return;
		SetTransformInternal(mTransformStack.PopBack());
	}

	// Multiplies the color of everything drawn afterwards (alpha fade, tinting).
	public GraphicsScope PushTint(Color color)
	{
		mTintStack.Add(mTint);
		mTint = mTint * color;
		return GraphicsScope(this, .Tint);
	}

	public void PopTint()
	{
		if (mTintStack.Count == 0)
			return;
		mTint = mTintStack.PopBack();
	}

	// Clips to `rect` given in the current (transformed) 2D space. Rotation is approximated by the bounding box.
	public GraphicsScope PushClip(Rect rect)
	{
		Flush();
		mClipStack.Add(mClip);

		let x0 = rect.mX * mM11 + rect.mY * mM21 + mM31;
		let y0 = rect.mX * mM12 + rect.mY * mM22 + mM32;
		let x1 = rect.mRight * mM11 + rect.mBottom * mM21 + mM31;
		let y1 = rect.mRight * mM12 + rect.mBottom * mM22 + mM32;
		var device = Rect(Math.Min(x0, x1), Math.Min(y0, y1), Math.Abs(x1 - x0), Math.Abs(y1 - y0));
		if (mClip.bEnabled)
			device = device.Intersection(mClip.mRect);
		mClip.mRect = device;
		mClip.bEnabled = true;
		return GraphicsScope(this, .Clip);
	}

	public void PopClip()
	{
		if (mClipStack.Count == 0)
			return;
		Flush();
		mClip = mClipStack.PopBack();
	}

	// ---------------------------------------------------------------------------------------------------------
	// Batching internals
	// ---------------------------------------------------------------------------------------------------------

	Vertex MakeVertex(float x, float y, float u, float v, Color color)
	{
		return Vertex(x * mM11 + y * mM21 + mM31, x * mM12 + y * mM22 + mM32, 0, u, v, color);
	}

	Color TintColor(Color color)
	{
		return color * mTint;
		//return Colors.PackRGBA(Colors.Multiply(color, mTint));
	}

	void SetBatchTexture(Texture2D texture)
	{
		SetTexture(texture, 0);
	}

	void EnsureSpace(int vertexCount, int indexCount)
	{
		Runtime.Assert(vertexCount <= (int)cMaxVertices && indexCount <= (int)cMaxIndices, "Graphics: primitive does not fit into the dynamic buffers");
		if (mVertices.CanFit(vertexCount) && mIndices.CanFit(indexCount))
			return;

		// Draw what we have, then start over with a fresh (discarded) buffer.
		Flush();
		mVertices.Unmap();
		mIndices.Unmap();
		mVertices.Reset();
		mIndices.Reset();
		mBatchIndexStart = 0;
		mVertices.Map(.WriteDiscard);
		mIndices.Map(.WriteDiscard);
	}

	void EmitQuad(Vertex a, Vertex b, Vertex c, Vertex d)
	{
		EnsureSpace(4, 6);
		let i = mVertices.Push(a, b, c, d);
		mIndices.PushUInt32(i, i + 1, i + 2, i, i + 2, i + 3);
		mBatchIndexCount += 6;
		mVerticesPushed += 4;
	}

	void EmitTriangle(Vertex a, Vertex b, Vertex c)
	{
		EnsureSpace(3, 3);
		let i = mVertices.Push(a, b, c);
		mIndices.PushUInt32(i, i + 1, i + 2);
		mBatchIndexCount += 3;
		mVerticesPushed += 3;
	}

	// Submits the pending batch. Safe to call at any time.
	public void Flush()
	{
		if (!bFrameActive || mBatchIndexCount == 0)
			return;

		mVertices.Unmap();
		mIndices.Unmap();

		ApplyPipeline(.TriangleList);
		Buffer* vb = mDynamicVB;
		c_uint stride = sizeof(Vertex);
		c_uint offset = 0;
		Juno.SetVertexBuffers(mDevice, 0, 1, &vb, &stride, &offset);
		Juno.SetIndexBuffer(mDevice, mDynamicIB, .UInt32, 0);
		Juno.DrawIndexed(mDevice, mBatchIndexCount, mBatchIndexStart, 0);
		mDrawCalls++;

		mBatchIndexStart += mBatchIndexCount;
		mBatchIndexCount = 0;

		// Keep appending behind the data the GPU may still be reading.
		mVertices.Map(.WriteNoOverwrite);
		mIndices.Map(.WriteNoOverwrite);
	}

	void ApplyPipeline(PrimitiveTopology topology)
	{
		let shader = (mShader != null) ? mShader : mDefaultShader;
		Juno.SetShader(mDevice, shader.mVertexShader);
		Juno.SetShader(mDevice, shader.mPixelShader);
		Juno.SetInputLayout(mDevice, shader.mInputLayout);
		Juno.SetPrimitiveTopology(mDevice, topology);

		Juno.SetBlendState(mDevice, mBlendStates[(int)mBlendMode], null, 0xFFFFFFFF);
		Juno.SetDepthStencilState(mDevice, mDepthStates[(int)mDepthMode], 0);
		Juno.SetRasterizerState(mDevice, GetRasterizerState(mCullMode, bWireframe, mClip.bEnabled));

		Sampler* sampler = mSamplers[(int)mSamplerKind];
		Juno.SetSamplers(mDevice, .Pixel, 0, 1, &sampler);

		Texture*[4] textures = default;
		for (int i < cTextureSlots)
			textures[i] = (mTextures[i] != null) ? mTextures[i].mHandle : null;
		Juno.SetTextures(mDevice, .Pixel, 0, 4, &textures[0]);

		if (bConstantsDirty)
		{
			FrameConstants frame = default;
			frame.mViewProjection = mViewProjection;
			frame.mTime = mTime;
			frame.mDeltaTime = mDeltaTime;
			frame.mViewportWidth = (float)mTargetWidth;
			frame.mViewportHeight = (float)mTargetHeight;
			Juno.UpdateBuffer(mDevice, mFrameCB, 0, &frame, (c_size)sizeof(FrameConstants));

			ObjectConstants obj = default;
			obj.mWorld = mWorld;
			obj.mTintR = (float)mObjectTint.mR / 255.0f;
			obj.mTintG = (float)mObjectTint.mG / 255.0f;
			obj.mTintB = (float)mObjectTint.mB / 255.0f;
			obj.mTintA = (float)mObjectTint.mA / 255.0f;
			Juno.UpdateBuffer(mDevice, mObjectCB, 0, &obj, (c_size)sizeof(ObjectConstants));
			bConstantsDirty = false;
		}
		Buffer*[2] constants = .(mFrameCB, mObjectCB);
		Juno.SetConstantBuffers(mDevice, .Vertex, 0, 2, &constants[0]);
		Juno.SetConstantBuffers(mDevice, .Pixel, 0, 2, &constants[0]);

		for (int i < cUserConstantBuffers)
		{
			if (mUserConstantBuffers[i] == null)
				continue;
			Buffer* buffer = mUserConstantBuffers[i].mHandle;
			Juno.SetConstantBuffers(mDevice, .Vertex, (c_uint)(2 + i), 1, &buffer);
			Juno.SetConstantBuffers(mDevice, .Pixel, (c_uint)(2 + i), 1, &buffer);
		}

		if (mClip.bEnabled)
		{
			let left = Math.Clamp((int32)Math.Floor(mClip.mRect.mX), 0, mTargetWidth);
			let top = Math.Clamp((int32)Math.Floor(mClip.mRect.mY), 0, mTargetHeight);
			let right = Math.Clamp((int32)Math.Ceiling(mClip.mRect.mRight), 0, mTargetWidth);
			let bottom = Math.Clamp((int32)Math.Ceiling(mClip.mRect.mBottom), 0, mTargetHeight);
			Scissor scissor = Scissor(left, top, Math.Max(left, right), Math.Max(top, bottom));
			Juno.SetScissorRects(mDevice, &scissor, 1);
		}
	}

	// ---------------------------------------------------------------------------------------------------------
	// Retained: static meshes
	// ---------------------------------------------------------------------------------------------------------

	public void DrawMesh(Mesh mesh, Matrix4x4 world, Texture2D texture = null)
	{
		DrawMesh(mesh, world, texture, Color.cWhite);
	}

	// Draws a static mesh immediately with the current shader / camera / depth / cull state.
	// world: model matrix (row-vector convention). tint multiplies the vertex colors.
	public void DrawMesh(Mesh mesh, Matrix4x4 world, Texture2D texture, Color tint)
	{
		Flush();

		let savedTexture = mTextures[0];
		mTextures[0] = (texture != null) ? texture : mWhiteTexture;
		mWorld = world;
		mObjectTint = tint;
		bConstantsDirty = true;

		ApplyPipeline(mesh.mTopology);
		Buffer* vb = mesh.mVertexBuffer;
		c_uint stride = mesh.mStride;
		c_uint offset = 0;
		Juno.SetVertexBuffers(mDevice, 0, 1, &vb, &stride, &offset);
		if (mesh.mIndexBuffer != null)
		{
			Juno.SetIndexBuffer(mDevice, mesh.mIndexBuffer, .UInt32, 0);
			Juno.DrawIndexed(mDevice, mesh.mIndexCount, 0, 0);
		}
		else
		{
			Juno.Draw(mDevice, mesh.mVertexCount, 0);
		}
		mDrawCalls++;

		mTextures[0] = savedTexture;
		mWorld = Matrix4x4.sIdentity;
		mObjectTint = Color.cWhite;
		bConstantsDirty = true;
	}

	// ---------------------------------------------------------------------------------------------------------
	// Immediate: raw geometry
	// ---------------------------------------------------------------------------------------------------------

	// Pushes triangles as they are: positions are NOT affected by the 2D transform stack (use this for 3D geometry
	// together with SetCamera). Indices are relative to the first vertex of this call.
	public void DrawVertices(Span<Vertex> vertices, Span<uint32> indices, Texture2D texture = null)
	{
		SetBatchTexture(texture);
		EnsureSpace(vertices.Length, indices.Length);
		let first = mVertices.mIndex;
		mVertices.Push(vertices);
		for (let index in indices)
			mIndices.PushUInt32(first + index);
		mBatchIndexCount += (uint32)indices.Length;
		mVerticesPushed += (int32)vertices.Length;
	}

	// ---------------------------------------------------------------------------------------------------------
	// Immediate: 2D shapes
	// ---------------------------------------------------------------------------------------------------------

	public void FillRect(float x, float y, float width, float height, Color color)
	{
		SetBatchTexture(null);
		let c = TintColor(color);
		EmitQuad(MakeVertex(x, y, 0, 0, c), MakeVertex(x + width, y, 1, 0, c), MakeVertex(x + width, y + height, 1, 1, c), MakeVertex(x, y + height, 0, 1, c));
	}

	public void FillRect(Rect rect, Color color)
	{
		FillRect(rect.mX, rect.mY, rect.mWidth, rect.mHeight, color);
	}

	public void FillRectGradient(Rect r, Color topLeft, Color topRight, Color bottomRight, Color bottomLeft)
	{
		SetBatchTexture(null);
		EmitQuad(
			MakeVertex(r.mX, r.mY, 0, 0, TintColor(topLeft)),
			MakeVertex(r.mRight, r.mY, 1, 0, TintColor(topRight)),
			MakeVertex(r.mRight, r.mBottom, 1, 1, TintColor(bottomRight)),
			MakeVertex(r.mX, r.mBottom, 0, 1, TintColor(bottomLeft)));
	}

	public void DrawRect(Rect r, Color color, float thickness = 1)
	{
		FillRect(r.mX, r.mY, r.mWidth, thickness, color);
		FillRect(r.mX, r.mBottom - thickness, r.mWidth, thickness, color);
		FillRect(r.mX, r.mY + thickness, thickness, r.mHeight - thickness * 2, color);
		FillRect(r.mRight - thickness, r.mY + thickness, thickness, r.mHeight - thickness * 2, color);
	}

	public void DrawLine(float x0, float y0, float x1, float y1, Color color, float thickness = 1)
	{
		let dx = x1 - x0;
		let dy = y1 - y0;
		let length = Math.Sqrt(dx * dx + dy * dy);
		if (length <= 0.0001f)
			return;

		let nx = -dy / length * thickness * 0.5f;
		let ny = dx / length * thickness * 0.5f;
		SetBatchTexture(null);
		let c = TintColor(color);
		EmitQuad(MakeVertex(x0 + nx, y0 + ny, 0, 0, c), MakeVertex(x1 + nx, y1 + ny, 1, 0, c),
			MakeVertex(x1 - nx, y1 - ny, 1, 1, c), MakeVertex(x0 - nx, y0 - ny, 0, 1, c));
	}

	public void FillTriangle(float x0, float y0, float x1, float y1, float x2, float y2, Color color)
	{
		SetBatchTexture(null);
		let c = TintColor(color);
		EmitTriangle(MakeVertex(x0, y0, 0, 0, c), MakeVertex(x1, y1, 1, 0, c), MakeVertex(x2, y2, 0, 1, c));
	}

	public void FillCircle(float cx, float cy, float radius, Color color, int segments = 32)
	{
		SetBatchTexture(null);
		let c = TintColor(color);
		let step = Math.PI_f * 2.0f / (float)segments;
		for (int i < segments)
		{
			let a0 = step * (float)i;
			let a1 = step * (float)(i + 1);
			EmitTriangle(MakeVertex(cx, cy, 0, 0, c),
				MakeVertex(cx + Math.Cos(a0) * radius, cy + Math.Sin(a0) * radius, 0, 0, c),
				MakeVertex(cx + Math.Cos(a1) * radius, cy + Math.Sin(a1) * radius, 0, 0, c));
		}
	}

	public void DrawCircle(float cx, float cy, float radius, Color color, float thickness = 1, int segments = 48)
	{
		let step = Math.PI_f * 2.0f / (float)segments;
		for (int i < segments)
		{
			let a0 = step * (float)i;
			let a1 = step * (float)(i + 1);
			DrawLine(cx + Math.Cos(a0) * radius, cy + Math.Sin(a0) * radius, cx + Math.Cos(a1) * radius, cy + Math.Sin(a1) * radius, color, thickness);
		}
	}

	// ---------------------------------------------------------------------------------------------------------
	// Immediate: textures
	// ---------------------------------------------------------------------------------------------------------

	public void DrawTexture(Texture2D texture, float x, float y, float width, float height)
	{
		DrawTexture(texture, x, y, width, height, Color.cWhite);
	}

	public void DrawTexture(Texture2D texture, float x, float y, float width, float height, Color tint)
	{
		SetBatchTexture(texture);
		let c = TintColor(tint);
		EmitQuad(MakeVertex(x, y, 0, 0, c), MakeVertex(x + width, y, 1, 0, c), MakeVertex(x + width, y + height, 1, 1, c), MakeVertex(x, y + height, 0, 1, c));
	}

	// source is in texture pixels.
	public void DrawTexture(Texture2D texture, Rect destination, Rect source, Color tint)
	{
		SetBatchTexture(texture);
		let c = TintColor(tint);
		let tw = (float)texture.mWidth;
		let th = (float)texture.mHeight;
		let u0 = source.mX / tw;
		let v0 = source.mY / th;
		let u1 = source.mRight / tw;
		let v1 = source.mBottom / th;
		EmitQuad(MakeVertex(destination.mX, destination.mY, u0, v0, c), MakeVertex(destination.mRight, destination.mY, u1, v0, c),
			MakeVertex(destination.mRight, destination.mBottom, u1, v1, c), MakeVertex(destination.mX, destination.mBottom, u0, v1, c));
	}

	// ---------------------------------------------------------------------------------------------------------
	// Text
	// ---------------------------------------------------------------------------------------------------------

	// Draws shaped text. (x, y) is the top-left corner of the text block. maxWidth > 0 enables word wrapping
	// (and is the alignment width). '\n' starts a new line.
	public void DrawString(Font font, StringView text, float x, float y, Color color, TextAlign align = .Left, float maxWidth = 0)
	{
		if (text.IsEmpty)
			return;

		font.Layout(text, maxWidth, mTextLayout);
		let c = TintColor(color);
		let blockWidth = (maxWidth > 0) ? maxWidth : mTextLayout.mWidth;

		for (let line in mTextLayout.mLines)
		{
			float offset = 0;
			if (align == .Center)
				offset = (blockWidth - line.mWidth) * 0.5f;
			else if (align == .Right)
				offset = blockWidth - line.mWidth;

			for (int i = line.mFirstGlyph; i < line.mFirstGlyph + line.mGlyphCount; i++)
			{
				let placed = mTextLayout.mGlyphs[i];
				let entry = font.GetGlyph(placed.mGlyph);
				if (!entry.bHasBitmap)
					continue;

				let gx = Math.Round(x + offset + placed.mX + entry.mBearingX);
				let gy = Math.Round(y + placed.mY - entry.mBearingY);
				SetBatchTexture(font.mPages[entry.mPage].mTexture);
				EmitQuad(
					MakeVertex(gx, gy, entry.mU0, entry.mV0, c),
					MakeVertex(gx + entry.mWidth, gy, entry.mU1, entry.mV0, c),
					MakeVertex(gx + entry.mWidth, gy + entry.mHeight, entry.mU1, entry.mV1, c),
					MakeVertex(gx, gy + entry.mHeight, entry.mU0, entry.mV1, c));
			}
		}
	}

	public Vector2 MeasureString(Font font, StringView text, float maxWidth = 0)
	{
		font.Layout(text, maxWidth, mTextLayout);
		return Vector2(mTextLayout.mWidth, mTextLayout.mHeight);
	}
}
