namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Elements;
using Shell.Widgets;
using Shell.Input;
using Shell.Platform;

// Runtime side of IWidgetHost: pointer capture state, cursor choice, and the services trusted controls use.
class WidgetHost : IWidgetHost
{
	public RuntimeContext mContext;
	public FocusManager mFocus;
	public Handle mCapture;
	public CursorKind mCursor = .Arrow;                 // what the platform bridge shows (updated by the InputRouter)
	public float mRootScreenX;                          // screen position of the window's client origin
	public float mRootScreenY;

	public IClipboardService mClipboard;
	public ITextInputService mTextInput;
	public IClock mClock;

	public this(RuntimeContext context)
	{
		mContext = context;
	}

	public Widget mCaptureWidget => mContext.Resolve<Widget>(mCapture);

	public void CapturePointer(Widget widget)
	{
		mCapture = widget.mHandle;
	}

	public void ReleasePointer(Widget widget)
	{
		if (mCapture == widget.mHandle)
			mCapture = Handle.sNone;
	}

	public bool IsPointerCaptured(Widget widget) => mCapture == widget.mHandle;
	public bool RequestFocus(Widget widget, FocusReason reason) => mFocus.SetFocus(widget, reason);

	public void ReleaseFocus(Widget widget)
	{
		if (mFocus.mFocused == widget)
			mFocus.Clear();
	}

	public bool HasFocus(Widget widget) => mFocus.mFocused == widget;

	public RectF RootToScreen(RectF rootRect)
	{
		return RectF(rootRect.mX + mRootScreenX, rootRect.mY + mRootScreenY, rootRect.mWidth, rootRect.mHeight);
	}

	public IClipboardService GetClipboard() => mClipboard;
	public ITextInputService GetTextInput() => mTextInput;
	public IClock GetClock() => mClock;
}
