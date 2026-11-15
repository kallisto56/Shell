namespace Juno;

using System;
using System.Collections;

// Win32 window implemented purely on the Beef side (x64). Direct P/Invoke, no native wrapper calls.
class Window
{
	const public String cClassName = "JunoWindowClass";
	const public int32 cUseDefault = int32.MinValue;

	static public bool bClassRegistered = false;
	static SetWindowCompositionAttributeFn sSetWindowCompositionAttribute = null;
	static bool sbCompositionAttributeLookedUp = false;

	public HWND mHandle = null;
	public bool bIsOpen = false;
	public bool bCloseRequested = false;
	public bool bResized = false;           // Set on WM_SIZE, cleared by the application.
	public bool bIsMinimized = false;
	public bool bHasFocus = false;
	public int32 mClientWidth = 0;
	public int32 mClientHeight = 0;
	public int32 mMouseX = 0;
	public int32 mMouseY = 0;
	public int32 mMouseWheelDelta = 0;
	public bool[256] mKeyDown;
	public bool[3] mMouseDown;              // Left, right, middle

	HICON mOwnedIconBig = null;
	HICON mOwnedIconSmall = null;

	public ~this()
	{
		Destroy();
	}

	// Call once at startup (before creating windows) for crisp rendering on high-DPI monitors.
	static public void EnableDpiAwareness()
	{
		var value = int(-4);
		NativeMethods.SetProcessDpiAwarenessContext((void*)value); // DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
	}

	public bool Create(CreateInfo createInfo)
	{
		var hInstance = NativeMethods.GetModuleHandleW(null);
		if (!bClassRegistered)
		{
			if (!RegisterWindowClass(hInstance))
				return false;
			bClassRegistered = true;
		}

		WINDOW_STYLE style = createInfo.mStyle;
		WINDOW_EX_STYLE exStyle = createInfo.mExStyle;

		// desc.mWidth/mHeight describe the client area.
		RECT rect = default;
		rect.right = createInfo.mWidth;
		rect.bottom = createInfo.mHeight;
		NativeMethods.AdjustWindowRectEx(&rect, (DWORD)style, 0, (DWORD)exStyle);

		let title = scope List<char16>();
		Wide.Encode(createInfo.mTitle, title);
		let className = scope List<char16>();
		Wide.Encode(cClassName, className);

		// `this` travels through lpCreateParams and is stored in GWLP_USERDATA during WM_NCCREATE.
		HWND hWnd = NativeMethods.CreateWindowExW((DWORD)exStyle, className.Ptr, title.Ptr, (DWORD)style,
			createInfo.mX, createInfo.mY, rect.right - rect.left, rect.bottom - rect.top,
			null, null, hInstance, Internal.UnsafeCastToPtr(this));
		if (hWnd == null)
			return false;

		mHandle = hWnd;
		bIsOpen = true;

		RECT client = default;
		NativeMethods.GetClientRect(hWnd, &client);
		mClientWidth = client.right - client.left;
		mClientHeight = client.bottom - client.top;

		if (createInfo.mExStyle.HasFlag(.WS_EX_LAYERED))
			NativeMethods.SetLayeredWindowAttributes(hWnd, 0, createInfo.mOpacity, .LWA_ALPHA);

		if (createInfo.bIsVisible)
		{
			NativeMethods.ShowWindow(hWnd, .SW_SHOW);
			NativeMethods.UpdateWindow(hWnd);

			if (createInfo.bIsCentered)
				this.SetPosition();
		}
		return true;
	}

	public void Destroy()
	{
		if (mHandle != null)
			NativeMethods.DestroyWindow(mHandle); // WM_DESTROY clears mHandle / bIsOpen.

		Icons.Destroy(mOwnedIconBig);
		Icons.Destroy(mOwnedIconSmall);
		mOwnedIconBig = null;
		mOwnedIconSmall = null;
	}

	// Pumps all pending messages of the calling thread.
	static public void PumpMessages()
	{
		MSG msg = default;
		while (NativeMethods.PeekMessageW(&msg, null, 0, 0, .PM_REMOVE) != 0)
		{
			NativeMethods.TranslateMessage(&msg);
			NativeMethods.DispatchMessageW(&msg);
		}
	}

	// Override to intercept messages. Return true (and set result) to stop default handling.
	public virtual bool OnMessage(UINT msg, WPARAM wParam, LPARAM lParam, ref LRESULT result)
	{
		return false;
	}

	public void SetTitle(StringView title)
	{
		let wide = scope List<char16>();
		Wide.Encode(title, wide);
		NativeMethods.SetWindowTextW(mHandle, wide.Ptr);
	}

	public bool IsKeyDown(KeyCode keyCode)
	{
		var key = keyCode.Underlying;
		return (key >= 0) && (key < 256) && (mKeyDown[key]);
	}

	public int32 ConsumeMouseWheel()
	{
		let delta = mMouseWheelDelta;
		mMouseWheelDelta = 0;
		return delta;
	}

	// ---- Icons -------------------------------------------------------------------------------------------------

	public void SetIcon(HICON big, HICON small)
	{
		Icons.SetWindowIcon(mHandle, big, small);
	}

	public bool SetIconFromFile(StringView path)
	{
		HICON icon = Icons.LoadFromFile(path);
		if (icon == null)
			return false;
		Icons.Destroy(mOwnedIconBig);
		Icons.Destroy(mOwnedIconSmall);
		mOwnedIconBig = icon;
		mOwnedIconSmall = null;
		Icons.SetWindowIcon(mHandle, icon, icon);
		return true;
	}

	// Uses the icon that is packed into the running executable. The window owns the extracted handles.
	public bool SetIconFromExecutable()
	{
		if (!Icons.ExtractFromExecutable(var large, var small))
			return false;
		Icons.Destroy(mOwnedIconBig);
		Icons.Destroy(mOwnedIconSmall);
		mOwnedIconBig = large;
		mOwnedIconSmall = small;
		Icons.SetWindowIcon(mHandle, large, small);
		return true;
	}

	// ---- OS visual effects -------------------------------------------------------------------------------------

	// Requires WindowDesc.bLayered (WS_EX_LAYERED).
	public void SetOpacity(uint8 alpha)
	{
		NativeMethods.SetLayeredWindowAttributes(mHandle, 0, alpha, .LWA_ALPHA);
	}

	public void SetDarkMode(bool enable)
	{
		BOOL value = enable ? 1 : 0;
		NativeMethods.DwmSetWindowAttribute(mHandle, .DWMWA_USE_IMMERSIVE_DARK_MODE, &value, (DWORD)sizeof(BOOL));
	}

	// Windows 11 22H2+: Mica / Acrylic / Tabbed backdrops. Needs ExtendFrameIntoClientArea for client-area visibility.
	public void SetSystemBackdrop(DWM_SYSTEMBACKDROP_TYPE type)
	{
		int32 value = (int32)type;
		NativeMethods.DwmSetWindowAttribute(mHandle, .DWMWA_SYSTEMBACKDROP_TYPE, &value, (DWORD)sizeof(int32));
	}

	public void SetCornerPreference(DWM_WINDOW_CORNER_PREFERENCE preference)
	{
		int32 value = (int32)preference;
		NativeMethods.DwmSetWindowAttribute(mHandle, .DWMWA_WINDOW_CORNER_PREFERENCE, &value, (DWORD)sizeof(int32));
	}

	// Extends the DWM frame over the whole client area (-1 margins = "sheet of glass").
	public void ExtendFrameIntoClientArea()
	{
		MARGINS margins = default;
		margins.cxLeftWidth = -1;
		margins.cxRightWidth = -1;
		margins.cyTopHeight = -1;
		margins.cyBottomHeight = -1;
		NativeMethods.DwmExtendFrameIntoClientArea(mHandle, &margins);
	}

	public void SetPosition(int x = int.MinValue, int y = int.MinValue)
	{
		if (!NativeMethods.GetWindowRect(this.mHandle, var rect))
		    return;

		var x;
		var y;

		var windowWidth = rect.right - rect.left;
		var windowHeight = rect.bottom - rect.top;
		var hMonitor = NativeMethods.MonitorFromWindow(this.mHandle, .MONITOR_DEFAULTTONEAREST);
		var mi = NativeMethods.MONITORINFOEXW();
		mi.cbSize = sizeof(NativeMethods.MONITORINFOEXW);

		var workWidth = default(LONG);
		var workHeight = default(LONG);

		if ((x == int.MinValue) || (y == int.MinValue))
		{
			if (NativeMethods.GetMonitorInfoW(hMonitor, &mi))
			{
			    workWidth = mi.rcWork.right - mi.rcWork.left;
			    workHeight = mi.rcWork.bottom - mi.rcWork.top;
			}
		}

		if (x == int.MinValue)
			x = mi.rcWork.left + (workWidth - windowWidth) / 2;

		if (y == int.MinValue)
			y = mi.rcWork.top + (workHeight - windowHeight) / 2;

		NativeMethods.SetWindowPos(this.mHandle, null, (.)x, (.)y, 0, 0, .SWP_NOSIZE | .SWP_NOZORDER);
	}

	// Undocumented but widely used user32 export (Windows 10+). gradientColor is 0xAABBGGRR.
	public bool SetAccent(ACCENT_STATE state, uint32 gradientColor = 0, int32 flags = 0)
	{
		if (!sbCompositionAttributeLookedUp)
		{
			sbCompositionAttributeLookedUp = true;
			HMODULE user32 = NativeMethods.GetModuleHandleA("user32.dll");
			void* proc = NativeMethods.GetProcAddress(user32, "SetWindowCompositionAttribute");
			sSetWindowCompositionAttribute = (SetWindowCompositionAttributeFn)proc;
		}
		if (sSetWindowCompositionAttribute == null)
			return false;

		ACCENT_POLICY accent = default;
		accent.AccentState = state;
		accent.AccentFlags = flags;
		accent.GradientColor = gradientColor;

		WINDOWCOMPOSITIONATTRIBDATA data = default;
		data.Attrib = .WCA_ACCENT_POLICY;
		data.pvData = &accent;
		data.cbData = (uint)sizeof(ACCENT_POLICY);
		return sSetWindowCompositionAttribute(mHandle, &data) != 0;
	}

	public bool EnableBlurBehind()
	{
		return SetAccent(.ACCENT_ENABLE_BLURBEHIND);
	}

	public bool EnableAcrylicBlurBehind(uint32 tintColor = 0x99000000)
	{
		return SetAccent(.ACCENT_ENABLE_ACRYLICBLURBEHIND, tintColor, 2);
	}

	public bool DisableAccent()
	{
		return SetAccent(.ACCENT_DISABLED);
	}

	// ---- Window procedure --------------------------------------------------------------------------------------

	static bool RegisterWindowClass(HINSTANCE hInstance)
	{
		let className = scope List<char16>();
		Wide.Encode(cClassName, className);

		WNDCLASSEXW wc = default;
		wc.cbSize = (UINT)sizeof(WNDCLASSEXW);
		wc.style = (UINT)(CLASS_STYLE.CS_HREDRAW | CLASS_STYLE.CS_VREDRAW | CLASS_STYLE.CS_OWNDC);
		wc.lpfnWndProc = => WndProc;
		wc.hInstance = hInstance;
		wc.hCursor = NativeMethods.LoadCursorW(null, (char16*)(void*)(int)IDC_CURSOR.IDC_ARROW);
		wc.lpszClassName = className.Ptr;
		return NativeMethods.RegisterClassExW(&wc) != 0;
	}

	[CallingConvention(.Stdcall)]
	static LRESULT WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
	{
		Window window = null;
		if (msg == (UINT)WM_MESSAGE.WM_NCCREATE)
		{
			let cs = (CREATESTRUCTW*)(void*)lParam;
			NativeMethods.SetWindowLongPtrW(hWnd, .GWLP_USERDATA, (int)cs.lpCreateParams);
			window = (Window)Internal.UnsafeCastToObject(cs.lpCreateParams);
			window.mHandle = hWnd;
		}
		else
		{
			void* ptr = (void*)NativeMethods.GetWindowLongPtrW(hWnd, .GWLP_USERDATA);
			if (ptr != null)
				window = (Window)Internal.UnsafeCastToObject(ptr);
		}

		if (window != null)
		{
			LRESULT result = 0;
			bool bHandled = window.HandleMessage(msg, wParam, lParam, ref result);
			if (msg == (UINT)WM_MESSAGE.WM_NCDESTROY)
				NativeMethods.SetWindowLongPtrW(hWnd, .GWLP_USERDATA, 0);
			if (bHandled)
				return result;
		}
		return NativeMethods.DefWindowProcW(hWnd, msg, wParam, lParam);
	}

	bool HandleMessage(UINT msg, WPARAM wParam, LPARAM lParam, ref LRESULT result)
	{
		if (OnMessage(msg, wParam, lParam, ref result))
			return true;

		switch ((WM_MESSAGE)msg)
		{
		case .WM_CLOSE:
			bCloseRequested = true; // The application decides when to call Destroy().
			return true;
		case .WM_DESTROY:
			bIsOpen = false;
			mHandle = null;
			return true;
		case .WM_ERASEBKGND:
			result = 1;
			return true;
		case .WM_SIZE:
			mClientWidth = (int32)(lParam & 0xFFFF);
			mClientHeight = (int32)((lParam >> 16) & 0xFFFF);
			bIsMinimized = (wParam == 1); // SIZE_MINIMIZED
			if (!bIsMinimized)
				bResized = true;
			return false;
		case .WM_SETFOCUS:
			bHasFocus = true;
			return false;
		case .WM_KILLFOCUS:
			bHasFocus = false;
			for (int i = 0; i < 256; i++)
				mKeyDown[i] = false;
			return false;
		case .WM_KEYDOWN, .WM_SYSKEYDOWN:
			mKeyDown[(int)(wParam & 0xFF)] = true;
			return false;
		case .WM_KEYUP, .WM_SYSKEYUP:
			mKeyDown[(int)(wParam & 0xFF)] = false;
			return false;
		case .WM_MOUSEMOVE:
			mMouseX = (int32)(int16)(lParam & 0xFFFF);
			mMouseY = (int32)(int16)((lParam >> 16) & 0xFFFF);
			return false;
		case .WM_LBUTTONDOWN: mMouseDown[0] = true; return false;
		case .WM_LBUTTONUP: mMouseDown[0] = false; return false;
		case .WM_RBUTTONDOWN: mMouseDown[1] = true; return false;
		case .WM_RBUTTONUP: mMouseDown[1] = false; return false;
		case .WM_MBUTTONDOWN: mMouseDown[2] = true; return false;
		case .WM_MBUTTONUP: mMouseDown[2] = false; return false;
		case .WM_MOUSEWHEEL:
			mMouseWheelDelta += (int32)(int16)((wParam >> 16) & 0xFFFF) / 120;
			return false;
		default:
			return false;
		}
	}

	
	[CRepr]
	public struct CreateInfo
	{
		public StringView mTitle = "Juno";
		public int32 mWidth = 1024;
		public int32 mHeight = 768;
		public int32 mX = int32.MinValue;
		public int32 mY = int32.MinValue;
		public WINDOW_STYLE mStyle = .WS_OVERLAPPEDWINDOW;
		public WINDOW_EX_STYLE mExStyle = .WS_EX_LEFT;
		public uint8 mOpacity = 255;
		public bool bIsVisible = true;
		public bool bIsCentered = true;
	}
}
