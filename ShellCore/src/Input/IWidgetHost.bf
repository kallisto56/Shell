namespace Shell.Input;

using System;
using Shell.Core;
using Shell.Widgets;
using Shell.Platform;

// What widgets may ask of the runtime around them: focus, pointer capture, cursor, coordinate conversion and the few
// platform services a trusted control needs (clipboard, text input, time). Implemented by the widget runtime (ShellRuntime).
interface IWidgetHost
{
	void CapturePointer(Widget widget);
	void ReleasePointer(Widget widget);
	bool IsPointerCaptured(Widget widget);
	bool RequestFocus(Widget widget, FocusReason reason);
	void ReleaseFocus(Widget widget);
	bool HasFocus(Widget widget);
	RectF RootToScreen(RectF rootRect);                 // for IME candidate windows
	IClipboardService GetClipboard();
	ITextInputService GetTextInput();
	IClock GetClock();
}
