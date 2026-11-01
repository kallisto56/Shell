namespace Shell.PlatformWin;

using System;
using System.Collections;
using Shell.Core;
using Shell.Input;
using Shell.Platform;
using Shell.Runtime;

// Translates the Win32 messages of the shell window into widget input events. The host calls HandleMessage() first from its
// window procedure; when it returns true the message is finished and `result` is the return value, otherwise the host continues
// with DefWindowProc. Works with any window implementation (the Juno framework window, the editor's host window ...).
//
// Handled: mouse move / buttons (with click counting) / wheel, keys (left and right modifiers distinguished, auto-repeat flagged),
// WM_CHAR text (surrogate pairs combined, control characters dropped), cursor selection, loss of focus (cancels pointer and
// composition, releases pressed keys), and - through WinTextInputService - all IME messages.
// Coordinates are window client coordinates, which is the root coordinate space of the widget tree.
class WinInputBridge
{
	const double cDoubleClickSeconds = 0.5;
	const float cDoubleClickDistance = 4;

	InputEventQueue mQueue;
	WidgetHost mHost;
	public WinTextInputService mTextInput;
	IClock mClock;

	bool[256] mKeys;
	int mButtonsDown;
	float mX;
	float mY;
	double[6] mLastClickTime;
	int32[6] mClickCount;
	float mClickX;
	float mClickY;
	uint32 mHighSurrogate;

	public this(InputEventQueue queue, WidgetHost host, IClock clock, WinTextInputService textInput = null)
	{
		mQueue = queue;
		mHost = host;
		mClock = clock;
		mTextInput = textInput;
	}

	KeyModifiers Modifiers()
	{
		var mods = KeyModifiers.None;
		if (mKeys[(int)Key.LShift] || mKeys[(int)Key.RShift]) mods |= .Shift;
		if (mKeys[(int)Key.LControl] || mKeys[(int)Key.RControl]) mods |= .Control;
		if (mKeys[(int)Key.LAlt] || mKeys[(int)Key.RAlt]) mods |= .Alt;
		if (mKeys[(int)Key.LWin] || mKeys[(int)Key.RWin]) mods |= .Super;
		return mods;
	}

	// Win32 reports generic Shift / Ctrl / Alt; the scan code / extended bit tell left from right.
	static Key Translate(uint wParam, int lParam)
	{
		let vk = (int32)(wParam & 0xFF);
		switch (vk)
		{
		case 0x10: return (((lParam >> 16) & 0xFF) == 0x36) ? Key.RShift : Key.LShift;
		case 0x11: return (((lParam >> 24) & 1) != 0) ? Key.RControl : Key.LControl;
		case 0x12: return (((lParam >> 24) & 1) != 0) ? Key.RAlt : Key.LAlt;
		default: return (Key)vk;
		}
	}

	void Pointer(PointerEventKind kind, PointerButton button, int32 clickCount, float wheelX = 0, float wheelY = 0)
	{
		PointerEvent e = default;
		e.mKind = kind;
		e.mX = mX;
		e.mY = mY;
		e.mButton = button;
		e.mClickCount = clickCount;
		e.mModifiers = Modifiers();
		e.mWheelX = wheelX;
		e.mWheelY = wheelY;
		mQueue.EnqueuePointer(e);
	}

	bool OnButton(void* hwnd, PointerButton button, bool down)
	{
		if (down)
		{
			if (mButtonsDown == 0)
				NativeInput.SetCapture(hwnd);
			mButtonsDown++;

			let now = mClock.GetMonotonicSeconds();
			let dx = mX - mClickX;
			let dy = mY - mClickY;
			let index = (int)button;
			if (now - mLastClickTime[index] <= cDoubleClickSeconds && dx * dx + dy * dy <= cDoubleClickDistance * cDoubleClickDistance)
				mClickCount[index]++;
			else
				mClickCount[index] = 1;
			mLastClickTime[index] = now;
			mClickX = mX;
			mClickY = mY;
			Pointer(.Down, button, mClickCount[index]);
		}
		else
		{
			if (mButtonsDown > 0)
				mButtonsDown--;
			if (mButtonsDown == 0)
				NativeInput.ReleaseCapture();
			Pointer(.Up, button, 0);
		}
		return false;
	}

	void SetCursorFromHost()
	{
		uint cursorId;
		switch (mHost.mCursor)
		{
		case .IBeam: cursorId = 32513;
		case .Wait: cursorId = 32514;
		case .Cross: cursorId = 32515;
		case .SizeAll: cursorId = 32646;
		case .Hand: cursorId = 32649;
		default: cursorId = 32512;      // IDC_ARROW
		}
		NativeInput.SetCursor(NativeInput.LoadCursorW(null, (char16*)cursorId));
	}

	public bool HandleMessage(void* hwnd, uint32 msg, uint wParam, int lParam, ref int result)
	{
		if (mTextInput != null && msg >= 0x010D && msg <= 0x010F || msg == WinMessages.cImeSetContext)
		{
			if (mTextInput != null && mTextInput.HandleMessage(hwnd, msg, wParam, lParam, ref result))
				return true;
		}

		switch (msg)
		{
		case WinMessages.cMouseMove:
			mX = (float)(int16)(lParam & 0xFFFF);
			mY = (float)(int16)((lParam >> 16) & 0xFFFF);
			Pointer(.Move, .None, 0);
			return false;

		case WinMessages.cLButtonDown: SetPosition(lParam); return OnButton(hwnd, .Left, true);
		case WinMessages.cLButtonUp: SetPosition(lParam); return OnButton(hwnd, .Left, false);
		case WinMessages.cRButtonDown: SetPosition(lParam); return OnButton(hwnd, .Right, true);
		case WinMessages.cRButtonUp: SetPosition(lParam); return OnButton(hwnd, .Right, false);
		case WinMessages.cMButtonDown: SetPosition(lParam); return OnButton(hwnd, .Middle, true);
		case WinMessages.cMButtonUp: SetPosition(lParam); return OnButton(hwnd, .Middle, false);
		case WinMessages.cXButtonDown, WinMessages.cXButtonUp:
		{
			SetPosition(lParam);
			let button = (((wParam >> 16) & 0xFFFF) == 1) ? PointerButton.X1 : PointerButton.X2;
			OnButton(hwnd, button, msg == WinMessages.cXButtonDown);
			result = 1;     // required by Windows for XBUTTON messages
			return true;
		}

		case WinMessages.cMouseWheel:
			Pointer(.Wheel, .None, 0, 0, (float)(int16)((wParam >> 16) & 0xFFFF) / 120.0f);
			return false;
		case WinMessages.cMouseHWheel:
			Pointer(.Wheel, .None, 0, (float)(int16)((wParam >> 16) & 0xFFFF) / 120.0f, 0);
			return false;

		case WinMessages.cKeyDown, WinMessages.cSysKeyDown, WinMessages.cKeyUp, WinMessages.cSysKeyUp:
		{
			if ((wParam & 0xFF) == 0xE5)    // VK_PROCESSKEY: the IME is handling this key
				return false;
			let down = (msg == WinMessages.cKeyDown || msg == WinMessages.cSysKeyDown);
			let key = Translate(wParam, lParam);
			if ((int32)key > 0 && (int32)key < 256)
				mKeys[(int)key] = down;

			KeyEvent e = default;
			e.mKey = key;
			e.mModifiers = Modifiers();
			e.bIsDown = down;
			e.bIsRepeat = down && ((lParam & 0x40000000) != 0);
			mQueue.EnqueueKey(e);

			// Alt and F10 must not open the (non-existent) system menu; Alt+F4 still closes the window.
			if ((msg == WinMessages.cSysKeyDown || msg == WinMessages.cSysKeyUp) && key != .F4)
			{
				result = 0;
				return true;
			}
			return false;
		}

		case WinMessages.cSysCommand:
			if ((wParam & 0xFFF0) == 0xF100)    // SC_KEYMENU
			{
				result = 0;
				return true;
			}
			return false;

		case WinMessages.cChar:
		{
			let code = (uint32)wParam;
			if (code >= 0xD800 && code <= 0xDBFF) { mHighSurrogate = code; return false; }
			var cp = code;
			if (code >= 0xDC00 && code <= 0xDFFF)
			{
				if (mHighSurrogate == 0) return false;
				cp = 0x10000 + ((mHighSurrogate - 0xD800) << 10) + (code - 0xDC00);
				mHighSurrogate = 0;
			}
			if (cp >= 0x20 && cp != 0x7F)
			{
				let text = scope String();
				text.Append((char32)cp);
				mQueue.EnqueueText(text);
			}
			return false;
		}

		case WinMessages.cKillFocus, WinMessages.cCaptureChanged:
			if (msg == WinMessages.cKillFocus)
			{
				for (int i < 256)
					mKeys[i] = false;
			}
			mButtonsDown = 0;
			mQueue.EnqueueCancel();
			return false;

		case WinMessages.cSetCursor:
			if ((lParam & 0xFFFF) == 1)     // HTCLIENT
			{
				SetCursorFromHost();
				result = 1;
				return true;
			}
			return false;

		default:
			return false;
		}
	}

	void SetPosition(int lParam)
	{
		mX = (float)(int16)(lParam & 0xFFFF);
		mY = (float)(int16)((lParam >> 16) & 0xFFFF);
	}
}
