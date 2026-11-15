namespace Juno;

using System;
using System.Interop;
using System.Collections;
using System.Diagnostics;
using System.IO;

// Container of a Juno application, modeled on Beefy's BFApp:
//
//     class Program : Application
//     {
//         public override void OnInit() { ... load resources ... }
//         public override void OnUpdate(float dt) { ... }
//         public override void OnDraw(Graphics g) { ... }
//         static int Main(String[] args) { Program app = scope .(); return app.Run(args); }
//     }
//
// Application creates the window, device, swap chain, Graphics, InputState and the widget root, runs the loop
// (message pump -> fixed updates -> update -> draw UI -> present) and tears everything down in the right order.
// Resources created through the Create*/Load* helpers are owned by the application and released at shutdown.
class Application
{
	public struct Settings
	{
		public StringView mTitle = "Juno Application";
		public int32 mWidth = 1280;
		public int32 mHeight = 720;
		public bool bVSync = true;
		public bool bDebugDevice = true;
		public PixelFormat mDepthFormat = .D32_Float;       // Unknown = no depth buffer
		public bool bDpiAware = true;
		public bool bIconFromExecutable = true;
		public int32 mDefaultFontSize = 16;
		public float mFixedTimeStep = 1.0f / 60.0f;
	}

	static public Application sApp;

	public Settings mSettings = .();

	public ApplicationWindow mWindow;
	public Device* mDevice;
	public SwapChain* mSwapChain;
	public Graphics mGraphics;
	public InputState mInput;
	public WidgetRoot mRoot;
	public Font mDefaultFont;
	public Color mClearColor = Color(24, 26, 34, 255);

	public double mTime;                    // seconds since Run()
	public float mDeltaTime;                // seconds of the last frame
	public int64 mFrameCount;
	public float mFPS;
	public int32 mWindowWidth;
	public int32 mWindowHeight;
	public bool bIsRunning;
	public int mExitCode;

	CursorKind mCursor = .Arrow;
	Stopwatch mClock;
	List<Object> mOwned = new .() ~ delete _;
	float mFixedAccumulator;
	double mFpsTimer;
	int32 mFpsFrames;

	public this()
	{
		Runtime.Assert(sApp == null, "Only one Application can exist");
		sApp = this;
	}

	public ~this()
	{
		sApp = null;
	}

	// ---------------------------------------------------------------------------------------------------------
	// Overridables
	// ---------------------------------------------------------------------------------------------------------

	public virtual void OnCommandLine(StringView argument) { }
	public virtual void OnInit() { }                            // device, graphics, UI root and default font exist
	public virtual void OnShutdown() { }                        // called before any GPU object is released
	public virtual void OnFixedUpdate(float deltaTime) { }      // Settings.mFixedTimeStep
	public virtual void OnUpdate(float deltaTime) { }
	public virtual void OnDraw(Graphics g) { }                  // 3D / 2D scene. The UI is drawn afterwards.
	public virtual void OnResize(int width, int height) { }
	public virtual bool OnClosing() { return true; }            // return false to veto closing the window

	// Raw input events. Not called for events the UI consumed. For polling use mInput.
	public virtual void OnKeyDown(KeyCode key, bool isRepeat) { }
	public virtual void OnKeyUp(KeyCode key) { }
	public virtual void OnChar(char32 c) { }
	public virtual void OnMouseDown(MouseButton button, float x, float y, int clickCount) { }
	public virtual void OnMouseUp(MouseButton button, float x, float y) { }
	public virtual void OnMouseMove(float x, float y) { }
	public virtual void OnMouseWheel(float dx, float dy) { }

	// ---------------------------------------------------------------------------------------------------------
	// Lifetime
	// ---------------------------------------------------------------------------------------------------------

	public int Run(String[] args = null)
	{
		if (args != null)
		{
			for (let arg in args)
				this.OnCommandLine(arg);
		}

		if (!this.Initialize())
		{
			this.Shutdown();
			return 1;
		}

		this.bIsRunning = true;
		this.OnInit();
		this.MainLoop();
		this.OnShutdown();
		this.Shutdown();
		return this.mExitCode;
	}

	public void Stop(int exitCode = 0)
	{
		this.mExitCode = exitCode;
		this.bIsRunning = false;
	}

	bool Initialize()
	{
		Juno.SetFatalErrorHandler(=> Juno.DefaultFatalError);
		Juno.ValidateInteropLayout();

		if (mSettings.bDpiAware)
			Window.EnableDpiAwareness();

		mWindow = new ApplicationWindow();
		mWindow.mApplication = this;
		Window.CreateInfo windowInfo = .();
		windowInfo.mTitle = mSettings.mTitle;
		windowInfo.mWidth = mSettings.mWidth;
		windowInfo.mHeight = mSettings.mHeight;
		if (!mWindow.Create(windowInfo))
		{
			Console.WriteLine("[Juno] Failed to create the window");
			return false;
		}
		if (mSettings.bIconFromExecutable)
			mWindow.SetIconFromExecutable();
		mWindowWidth = mWindow.mClientWidth;
		mWindowHeight = mWindow.mClientHeight;

		Device.CreateInfo deviceInfo = .();
		deviceInfo.bDebug = mSettings.bDebugDevice;
		if (!JunoLog.Check(Juno.CreateDevice(&deviceInfo, out mDevice), "CreateDevice"))
			return false;

		SwapChain.CreateInfo swapChainInfo = .();
		swapChainInfo.mDevice = mDevice;
		swapChainInfo.mWindow = mWindow.mHandle;
		swapChainInfo.mDepthFormat = mSettings.mDepthFormat;
		if (!JunoLog.Check(Juno.CreateSwapChain(&swapChainInfo, out mSwapChain), "CreateSwapChain"))
			return false;

		mGraphics = new Graphics();
		if (!mGraphics.Initialize(mDevice))
			return false;

		mInput = new InputState();
		mRoot = new WidgetRoot();
		mRoot.SetBounds(0, 0, (float)mWindowWidth, (float)mWindowHeight);

		if (LoadSystemFont(mSettings.mDefaultFontSize) case .Ok(let font))
			mDefaultFont = font;
		else
			Console.WriteLine("[Juno] No default font found. Text will not be drawn until Application.mDefaultFont is set.");

		mClock = new Stopwatch();
		mClock.Start();
		return true;
	}

	void Shutdown()
	{
		// UI first (it references fonts), then user resources in reverse creation order, then Graphics and the device.
		delete mRoot;
		mRoot = null;

		for (var i = mOwned.Count - 1; i >= 0; i--)
			delete mOwned[i];
		mOwned.Clear();
		mDefaultFont = null;        // owned list released it

		delete mGraphics;
		mGraphics = null;
		delete mInput;
		mInput = null;

		if (mSwapChain != null)
		{
			Juno.DestroySwapChain(mSwapChain);
			mSwapChain = null;
		}
		if (mDevice != null)
		{
			Juno.DestroyDevice(mDevice);
			mDevice = null;
		}
		if (mWindow != null)
		{
			mWindow.Destroy();
			delete mWindow;
			mWindow = null;
		}
		delete mClock;
		mClock = null;
	}

	// ---------------------------------------------------------------------------------------------------------
	// Main loop
	// ---------------------------------------------------------------------------------------------------------

	void MainLoop()
	{
		double previous = (double)mClock.ElapsedMicroseconds / 1000000.0;

		while (bIsRunning && mWindow.bIsOpen)
		{
			Window.PumpMessages();
			if (!mWindow.bIsOpen)
				break;

			if (mWindow.bCloseRequested)
			{
				mWindow.bCloseRequested = false;
				if (OnClosing())
				{
					Stop();
					break;
				}
			}

			if (mWindow.bIsMinimized)
			{
				System.Threading.Thread.Sleep(10);
				previous = (double)mClock.ElapsedMicroseconds / 1000000.0;
				continue;
			}

			if (mWindow.bResized)
				HandleResize();

			let now = (double)mClock.ElapsedMicroseconds / 1000000.0;
			mDeltaTime = (float)Math.Min(now - previous, 0.25);
			previous = now;
			mTime = now;

			mFpsFrames++;
			mFpsTimer += mDeltaTime;
			if (mFpsTimer >= 0.5)
			{
				mFPS = (float)mFpsFrames / (float)mFpsTimer;
				mFpsFrames = 0;
				mFpsTimer = 0;
			}

			mFixedAccumulator += mDeltaTime;
			var steps = 0;
			while (mFixedAccumulator >= mSettings.mFixedTimeStep && steps < 8)
			{
				OnFixedUpdate(mSettings.mFixedTimeStep);
				mFixedAccumulator -= mSettings.mFixedTimeStep;
				steps++;
			}
			if (steps == 8)
				mFixedAccumulator = 0;

			mRoot.UpdateAll(mDeltaTime);
			OnUpdate(mDeltaTime);
			RenderFrame();

			mInput.EndFrame();
			mFrameCount++;
		}
	}

	void HandleResize()
	{
		mWindow.bResized = false;
		if (!JunoLog.Check(Juno.ResizeSwapChain(mSwapChain, 0, 0), "ResizeSwapChain"))
			return;

		mWindowWidth = mWindow.mClientWidth;
		mWindowHeight = mWindow.mClientHeight;
		mRoot.Resize((float)mWindowWidth, (float)mWindowHeight);
		OnResize(mWindowWidth, mWindowHeight);
	}

	void RenderFrame()
	{
		let g = mGraphics;
		g.BeginFrame(mSwapChain, (float)mTime, mDeltaTime);
		g.Clear(mClearColor);
		g.ClearDepth();

		OnDraw(g);

		g.ResetState();
		mRoot.DrawAll(g);
		g.EndFrame();

		let result = Juno.Present(mSwapChain, mSettings.bVSync);
		if (result == .DeviceLost)
		{
			JunoLog.Check(result, "Present");
			Stop(2);
		}
	}

	// ---------------------------------------------------------------------------------------------------------
	// Input plumbing (called by ApplicationWindow)
	// ---------------------------------------------------------------------------------------------------------

	public void HandleKeyDown(KeyCode key, bool isRepeat)
	{
		mInput.NotifyKeyDown(key, isRepeat);
		if (!mRoot.HandleKeyDown(key, mInput.mModifiers, isRepeat))
			OnKeyDown(key, isRepeat);
	}

	public void HandleKeyUp(KeyCode key)
	{
		mInput.NotifyKeyUp(key);
		if (!mRoot.HandleKeyUp(key, mInput.mModifiers))
			OnKeyUp(key);
	}

	public void HandleChar(char32 c)
	{
		mInput.NotifyText(c);
		if (!mRoot.HandleTextInput(c))
			OnChar(c);
	}

	public void HandleMouseMove(float x, float y)
	{
		mInput.NotifyMouseMove(x, y);
		if (!mRoot.HandleMouseMove(x, y, mInput.mModifiers))
			OnMouseMove(x, y);
	}

	public void HandleMouseButton(MouseButton button, bool down)
	{
		let x = mInput.mMousePosition.mX;
		let y = mInput.mMousePosition.mY;
		let clicks = mInput.NotifyMouseButton(button, down, mTime);
		if (!mRoot.HandleMouseButton(button, down, x, y, clicks, mInput.mModifiers))
		{
			if (down)
				OnMouseDown(button, x, y, clicks);
			else
				OnMouseUp(button, x, y);
		}
	}

	public void HandleMouseWheel(float dx, float dy)
	{
		mInput.NotifyWheel(dx, dy);
		if (!mRoot.HandleMouseWheel(dx, dy, mInput.mModifiers))
			OnMouseWheel(dx, dy);
	}

	public void HandleFocusLost()
	{
		mInput?.ReleaseAll();
	}

	// ---------------------------------------------------------------------------------------------------------
	// Cursor
	// ---------------------------------------------------------------------------------------------------------

	public void SetCursor(CursorKind cursor)
	{
		mCursor = cursor;
		ApplyCursor();
	}

	public void ApplyCursor()
	{
		IDC_CURSOR id = .IDC_ARROW;
		switch (mCursor)
		{
		case .Arrow: id = .IDC_ARROW;
		case .IBeam: id = .IDC_IBEAM;
		case .Hand: id = .IDC_HAND;
		case .Cross: id = .IDC_CROSS;
		case .Wait: id = .IDC_WAIT;
		case .SizeAll: id = .IDC_SIZEALL;
		}
		NativeMethods.SetCursor(NativeMethods.LoadCursorW(null, (c_wchar*)(void*)id.Underlying));
	}

	// ---------------------------------------------------------------------------------------------------------
	// Resource helpers. Everything returned here is owned by the application and deleted at shutdown
	// (call Release() to free something earlier).
	// ---------------------------------------------------------------------------------------------------------

	public T Own<T>(T resource) where T : class
	{
		mOwned.Add(resource);
		return resource;
	}

	public void Release(Object resource)
	{
		if (mOwned.Remove(resource))
			delete resource;
	}

	public Result<Texture2D> LoadTexture(StringView path, bool generateMips = true, bool srgb = false)
	{
		let result = Texture2D.FromFile(mDevice, path, generateMips, srgb);
		if (result case .Ok(let texture))
			mOwned.Add(texture);
		return result;
	}

	public Result<Texture2D> CreateTexture(int width, int height, uint8* rgba, bool generateMips = true)
	{
		let result = Texture2D.FromRGBA(mDevice, width, height, rgba, generateMips);
		if (result case .Ok(let texture))
			mOwned.Add(texture);
		return result;
	}

	public Result<RenderTarget> CreateRenderTarget(int width, int height, PixelFormat format = .R8G8B8A8_UNorm, bool withDepth = true)
	{
		let result = RenderTarget.Create(mDevice, width, height, format, withDepth);
		if (result case .Ok(let target))
			mOwned.Add(target);
		return result;
	}

	// Compiles a shader file / source with VSMain + PSMain. Uses the default Vertex layout unless one is given.
	public Result<ShaderProgram> CreateShader(StringView source, StringView name = "shader", VertexLayout layout = null)
	{
		let result = ShaderProgram.Create(mDevice, source, (layout != null) ? layout : mGraphics.mVertexLayout, name);
		if (result case .Ok(let program))
			mOwned.Add(program);
		return result;
	}

	public Result<ShaderProgram> LoadShader(StringView path, VertexLayout layout = null)
	{
		let result = ShaderProgram.FromFile(mDevice, path, (layout != null) ? layout : mGraphics.mVertexLayout);
		if (result case .Ok(let program))
			mOwned.Add(program);
		return result;
	}

	public Result<Mesh> CreateMesh<T>(Span<T> vertices, Span<uint32> indices = default, PrimitiveTopology topology = .TriangleList) where T : struct
	{
		let result = Mesh.Create<T>(mDevice, vertices, indices, topology);
		if (result case .Ok(let mesh))
			mOwned.Add(mesh);
		return result;
	}

	public Result<Mesh> CreateCubeMesh(float size)
	{
		let result = Mesh.CreateCube(mDevice, size);
		if (result case .Ok(let mesh))
			mOwned.Add(mesh);
		return result;
	}

	public Result<ConstantBuffer> CreateConstantBuffer(int size)
	{
		let result = ConstantBuffer.Create(mDevice, size);
		if (result case .Ok(let buffer))
			mOwned.Add(buffer);
		return result;
	}

	public Result<Font> LoadFont(StringView path, int pixelSize)
	{
		let result = Font.Load(mDevice, path, pixelSize);
		if (result case .Ok(let font))
			mOwned.Add(font);
		return result;
	}

	// Segoe UI / Tahoma / Arial from the Windows fonts folder.
	public Result<Font> LoadSystemFont(int pixelSize)
	{
		String[4] candidates = .("C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/tahoma.ttf", "C:/Windows/Fonts/arial.ttf", "C:/Windows/Fonts/calibri.ttf");
		for (let path in candidates)
		{
			if (File.Exists(path))
				return LoadFont(path, pixelSize);
		}
		return .Err;
	}
}
