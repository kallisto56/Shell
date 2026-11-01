namespace Shell.Input;

using System;

// Committed text (already composed by the keyboard layout / IME). mText is UTF-8 and valid only during the call.
struct TextInputEvent
{
	public StringView mText;
	public bool bHandled;
}
