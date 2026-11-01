namespace Shell.PlatformWin;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

// IME integration through IMM32 (works for all Windows 10 input method editors).
//
// The input bridge forwards the WM_IME_* messages of the shell window to HandleMessage(). The service draws no composition window of its
// own: it passes composition text to the attached ITextInputClient (the focused TextBox), which shows it through its skin, and it
// keeps the system's candidate window next to the caret (client.GetCaretRect()). Committed text is inserted with
// ReplaceText over the current selection. Because the messages are consumed here, Windows does not additionally send WM_CHAR for
// the committed text (no duplicates).
class WinTextInputService : ITextInputService
{
	const uint32 cGcsCompStr = 0x0008;
	const uint32 cGcsCursorPos = 0x0080;
	const uint32 cGcsResultStr = 0x0800;
	const uint32 cCfsPoint = 0x0002;
	const uint32 cCfsCandidatePos = 0x0040;

	ITextInputClient mClient;
	void* mHwnd;

	public void Attach(ITextInputClient client)
	{
		mClient = client;
		UpdateWindows();
	}

	public void Detach(ITextInputClient client)
	{
		if (mClient != client)
			return;
		if (mHwnd != null)
		{
			let himc = NativeImm32.ImmGetContext(mHwnd);
			if (himc != null)
			{
				NativeImm32.ImmNotifyIME(himc, 0x15, 4, 0);     // NI_COMPOSITIONSTR, CPS_CANCEL
				NativeImm32.ImmReleaseContext(mHwnd, himc);
			}
		}
		mClient = null;
	}

	public void NotifyCaretMoved()
	{
		UpdateWindows();
	}

	// Positions the system composition / candidate windows at the caret.
	void UpdateWindows()
	{
		if (mClient == null || mHwnd == null)
			return;
		let himc = NativeImm32.ImmGetContext(mHwnd);
		if (himc == null)
			return;

		let caret = mClient.GetCaretRect();         // screen coordinates
		POINT point = default;
		point.x = (int32)caret.mX;
		point.y = (int32)caret.mY;
		NativeInput.ScreenToClient(mHwnd, &point);

		COMPOSITIONFORM composition = default;
		composition.dwStyle = cCfsPoint;
		composition.ptCurrentPos = point;
		NativeImm32.ImmSetCompositionWindow(himc, &composition);

		CANDIDATEFORM candidate = default;
		candidate.dwIndex = 0;
		candidate.dwStyle = cCfsCandidatePos;
		candidate.ptCurrentPos = point;
		candidate.ptCurrentPos.y += (int32)caret.mHeight;
		NativeImm32.ImmSetCandidateWindow(himc, &candidate);
		NativeImm32.ImmReleaseContext(mHwnd, himc);
	}

	bool ReadString(void* himc, uint32 which, String output)
	{
		let bytes = NativeImm32.ImmGetCompositionStringW(himc, which, null, 0);
		if (bytes <= 0)
			return false;
		let buffer = scope List<char16>();
		for (int i < (bytes / 2) + 1)
			buffer.Add((char16)0);
		NativeImm32.ImmGetCompositionStringW(himc, which, buffer.Ptr, (uint32)bytes);
		WideString.Decode(buffer.Ptr, output, bytes / 2);
		return true;
	}

	// Returns true when the message was consumed (result is set).
	public bool HandleMessage(void* hwnd, uint32 msg, uint wParam, int lParam, ref int result)
	{
		mHwnd = hwnd;
		switch (msg)
		{
		case WinMessages.cImeSetContext:
			// Hide the system's composition window: the text box renders the composition itself.
			result = NativeInput.DefWindowProcW(hwnd, msg, wParam, lParam & ~(int)0x80000000);
			return true;

		case WinMessages.cImeStartComposition:
			result = 0;
			return true;

		case WinMessages.cImeEndComposition:
			if (mClient != null)
				mClient.SetComposition("", 0);
			result = 0;
			return true;

		case WinMessages.cImeComposition:
		{
			if (mClient == null)
				return false;
			let himc = NativeImm32.ImmGetContext(hwnd);
			if (himc == null)
				return false;

			if (((uint32)lParam & cGcsResultStr) != 0)
			{
				let committed = scope String();
				if (ReadString(himc, cGcsResultStr, committed))
				{
					mClient.GetSelection(var start, var end);
					mClient.SetComposition("", 0);
					mClient.ReplaceText(start, end, committed);
				}
			}
			if (((uint32)lParam & cGcsCompStr) != 0)
			{
				let composing = scope String();
				ReadString(himc, cGcsCompStr, composing);
				let cursor = NativeImm32.ImmGetCompositionStringW(himc, cGcsCursorPos, null, 0);
				mClient.SetComposition(composing, (int)Math.Max(cursor, 0));
			}
			NativeImm32.ImmReleaseContext(hwnd, himc);
			UpdateWindows();
			result = 0;
			return true;
		}
		default:
			return false;
		}
	}
}
