namespace Juno;

using System;

// Window that translates Win32 messages into Application input events. Uses Window.OnMessage, so the base
// window keeps handling size / focus / close as before.
class ApplicationWindow : Window
{
	public Application mApplication;
	uint32 mPendingHighSurrogate;
	int32 mButtonsDown;

	public override bool OnMessage(UINT msg, WPARAM wParam, LPARAM lParam, ref LRESULT result)
	{
		switch ((WM_MESSAGE)msg)
		{
		case .WM_KEYDOWN, .WM_SYSKEYDOWN:
			let key = TranslateKey(wParam, lParam);
			mApplication.HandleKeyDown(key, (lParam & 0x40000000) != 0);
			if (msg == (UINT)WM_MESSAGE.WM_SYSKEYDOWN && key != .F4)
			{
				result = 0;     // keeps Alt / F10 from opening the (non-existent) system menu
				return true;
			}
			return false;

		case .WM_KEYUP, .WM_SYSKEYUP:
			let key = TranslateKey(wParam, lParam);
			mApplication.HandleKeyUp(key);
			if (msg == (UINT)WM_MESSAGE.WM_SYSKEYUP && key != .F4)
			{
				result = 0;
				return true;
			}
			return false;

		case .WM_SYSCOMMAND:
			if ((wParam & 0xFFF0) == 0xF100)    // SC_KEYMENU
			{
				result = 0;
				return true;
			}
			return false;

		case .WM_CHAR:
			let code = (uint32)wParam;
			if (code >= 0xD800 && code <= 0xDBFF)
			{
				mPendingHighSurrogate = code;
			}
			else if (code >= 0xDC00 && code <= 0xDFFF)
			{
				if (mPendingHighSurrogate != 0)
				{
					let cp = 0x10000 + ((mPendingHighSurrogate - 0xD800) << 10) + (code - 0xDC00);
					mApplication.HandleChar((char32)cp);
				}
				mPendingHighSurrogate = 0;
			}
			else if (code >= 32 && code != 127)
			{
				mApplication.HandleChar((char32)code);
			}
			return false;

		case .WM_MOUSEMOVE:
			mApplication.HandleMouseMove((float)(int16)(lParam & 0xFFFF), (float)(int16)((lParam >> 16) & 0xFFFF));
			return false;

		case .WM_LBUTTONDOWN: return Button(.Left, true, lParam, ref result, false);
		case .WM_LBUTTONUP: return Button(.Left, false, lParam, ref result, false);
		case .WM_RBUTTONDOWN: return Button(.Right, true, lParam, ref result, false);
		case .WM_RBUTTONUP: return Button(.Right, false, lParam, ref result, false);
		case .WM_MBUTTONDOWN: return Button(.Middle, true, lParam, ref result, false);
		case .WM_MBUTTONUP: return Button(.Middle, false, lParam, ref result, false);
		case .WM_XBUTTONDOWN: return Button((((wParam >> 16) & 0xFFFF) == 1) ? .X1 : .X2, true, lParam, ref result, true);
		case .WM_XBUTTONUP: return Button((((wParam >> 16) & 0xFFFF) == 1) ? .X1 : .X2, false, lParam, ref result, true);

		case .WM_MOUSEWHEEL:
			mApplication.HandleMouseWheel(0, (float)(int16)((wParam >> 16) & 0xFFFF) / 120.0f);
			return false;

		case .WM_MOUSEHWHEEL:
			mApplication.HandleMouseWheel((float)(int16)((wParam >> 16) & 0xFFFF) / 120.0f, 0);
			return false;

		case .WM_KILLFOCUS:
			mApplication.HandleFocusLost();
			return false;

		case .WM_SETCURSOR:
			if ((lParam & 0xFFFF) == 1)     // HTCLIENT
			{
				mApplication.ApplyCursor();
				result = 1;
				return true;
			}
			return false;

		default:
			return false;
		}
	}

	bool Button(MouseButton button, bool down, LPARAM lParam, ref LRESULT result, bool bExtended)
	{
		// Keep receiving the mouse while a button is held, even outside of the window.
		if (down)
		{
			if (mButtonsDown == 0)
				NativeMethods.SetCapture(mHandle);
			mButtonsDown++;
		}
		else if (mButtonsDown > 0)
		{
			mButtonsDown--;
			if (mButtonsDown == 0)
				NativeMethods.ReleaseCapture();
		}

		let x = (float)(int16)(lParam & 0xFFFF);
		let y = (float)(int16)((lParam >> 16) & 0xFFFF);
		mApplication.HandleMouseMove(x, y);
		mApplication.HandleMouseButton(button, down);
		if (bExtended)
		{
			result = 1;     // required by Windows for XBUTTON messages
			return true;
		}
		return false;
	}

	// Win32 reports generic Shift / Ctrl / Alt; use scan code / extended bit to tell left from right.
	static KeyCode TranslateKey(WPARAM wParam, LPARAM lParam)
	{
		let vk = (int32)(wParam & 0xFF);
		switch (vk)
		{
		case 0x10:  // VK_SHIFT
			return (((lParam >> 16) & 0xFF) == 0x36) ? .RShift : .LShift;
		case 0x11:  // VK_CONTROL
			return (((lParam >> 24) & 1) != 0) ? .RControl : .LControl;
		case 0x12:  // VK_MENU
			return (((lParam >> 24) & 1) != 0) ? .RAlt : .LAlt;
		default:
			return (KeyCode)vk;
		}
	}
}
