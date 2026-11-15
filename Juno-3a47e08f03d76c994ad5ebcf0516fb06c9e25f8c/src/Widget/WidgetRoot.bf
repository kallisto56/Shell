namespace Juno;

using System;
using System.Collections;

// Root of a widget tree. Fills the window and routes input:
//   * mouse hover tracking (enter / leave / move)
//   * mouse capture: the widget that received a button press gets all mouse events until the button is released
//   * keyboard focus (click on a focusable widget, Tab / Shift+Tab to cycle)
//   * bubbling of unhandled events from the target up to its parents
// All Handle* methods return true when the UI consumed the event (so the game can ignore it).
class WidgetRoot : Widget
{
	public Widget mHover;
	public Widget mFocus;
	public Widget mCapture;
	float mLastX;
	float mLastY;

	public this()
	{
		this.bHitTestVisible = false;       // the empty background is not "UI"
	}

	// True while the mouse is over a widget or a widget holds the capture.
	public bool mWantsMouse => this.mHover != null || this.mCapture != null;
	public bool mWantsKeyboard => this.mFocus != null;

	// Called by Widget when it is removed from the tree or deleted, so no dangling pointers stay behind.
	public void OnWidgetRemoved(Widget widget)
	{
		if (this.mHover != null && this.IsSameOrDescendant(this.mHover, widget)) this.mHover = null;
		if (this.mFocus != null && this.IsSameOrDescendant(this.mFocus, widget)) this.mFocus = null;
		if (this.mCapture != null && this.IsSameOrDescendant(this.mCapture, widget)) this.mCapture = null;
	}

	bool IsSameOrDescendant(Widget candidate, Widget ancestor)
	{
		Widget w = candidate;
		while (w != null)
		{
			if (w == ancestor)
				return true;
			w = w.mParent;
		}
		return false;
	}

	// ---------------------------------------------------------------------------------------------------------
	// Mouse
	// ---------------------------------------------------------------------------------------------------------

	MouseEventArgs MakeArgs(Widget target, float rootX, float rootY, MouseButton button, int clickCount, KeyModifiers mods)
	{
		let local = target.RootToLocal(rootX, rootY);
		MouseEventArgs args = default;
		args.mX = local.mX;
		args.mY = local.mY;
		args.mButton = button;
		args.mClickCount = (int32)clickCount;
		args.mModifiers = mods;
		return args;
	}

	void UpdateHover(float x, float y)
	{
		Widget target = null;
		if (this.mCapture != null)
			target = this.mCapture;
		else
		{
			target = this.FindWidgetAt(x, y);
			if (target == this)
				target = null;
		}

		if (target == this.mHover)
			return;

		if (this.mHover != null)
		{
			this.mHover.bMouseOver = false;
			this.mHover.OnMouseLeave();
		}
		this.mHover = target;
		if (this.mHover != null)
		{
			this.mHover.bMouseOver = true;
			this.mHover.OnMouseEnter();
		}
	}

	public bool HandleMouseMove(float x, float y, KeyModifiers mods)
	{
		this.mLastX = x;
		this.mLastY = y;
		this.UpdateHover(x, y);

		if (this.mHover != null)
		{
			let args = this.MakeArgs(this.mHover, x, y, .Left, 0, mods);
			this.mHover.OnMouseMove(args);
		}
		return this.mWantsMouse;
	}

	public bool HandleMouseButton(MouseButton button, bool down, float x, float y, int clickCount, KeyModifiers mods)
	{
		this.mLastX = x;
		this.mLastY = y;

		if (down)
		{
			this.UpdateHover(x, y);
			let target = this.mHover;
			if (target == null)
			{
				this.SetFocus(null);
				return false;
			}

			this.mCapture = target;
			target.bPressed = true;

			// Focus the nearest focusable widget in the chain.
			Widget focusTarget = target;
			while (focusTarget != null && !focusTarget.bFocusable)
				focusTarget = focusTarget.mParent;
			this.SetFocus((focusTarget != this) ? focusTarget : null);

			Widget w = target;
			while (w != null && w != this)
			{
				var args = this.MakeArgs(w, x, y, button, clickCount, mods);
				w.OnMouseDown(ref args);
				w.mOnMouseDown(w, args);
				if (args.bHandled)
					break;
				w = w.mParent;
			}
			return true;
		}

		// Release
		let captured = this.mCapture;
		if (captured == null)
			return false;

		var args = this.MakeArgs(captured, x, y, button, clickCount, mods);
		captured.OnMouseUp(ref args);
		captured.mOnMouseUp(captured, args);
		captured.bPressed = false;

		let local = captured.RootToLocal(x, y);
		if (button == .Left && captured.HitTest(local.mX, local.mY))
		{
			captured.OnClick(args);
			captured.mOnClick(captured);
		}

		this.mCapture = null;
		this.UpdateHover(x, y);
		return true;
	}

	public bool HandleMouseWheel(float dx, float dy, KeyModifiers mods)
	{
		this.UpdateHover(this.mLastX, this.mLastY);
		Widget w = this.mHover;
		if (w == null)
			return false;

		while (w != null && w != this)
		{
			var args = this.MakeArgs(w, this.mLastX, this.mLastY, .Middle, 0, mods);
			args.mWheelX = dx;
			args.mWheelY = dy;
			w.OnMouseWheel(ref args);
			if (args.bHandled)
				return true;
			w = w.mParent;
		}
		return true;
	}

	// ---------------------------------------------------------------------------------------------------------
	// Keyboard
	// ---------------------------------------------------------------------------------------------------------

	public void SetFocus(Widget widget)
	{
		if (this.mFocus == widget)
			return;

		if (this.mFocus != null)
		{
			this.mFocus.bHasFocus = false;
			this.mFocus.OnLostFocus();
		}
		this.mFocus = widget;
		if (this.mFocus != null)
		{
			this.mFocus.bHasFocus = true;
			this.mFocus.OnGotFocus();
		}
	}

	public bool HandleKeyDown(KeyCode key, KeyModifiers mods, bool isRepeat)
	{
		Widget w = this.mFocus;
		while (w != null && w != this)
		{
			KeyEventArgs args = default;
			args.mKey = key;
			args.mModifiers = mods;
			args.bIsRepeat = isRepeat;
			w.OnKeyDown(ref args);
			w.mOnKeyDown(w, args);
			if (args.bHandled)
				return true;
			w = w.mParent;
		}

		if (key == .Tab)
		{
			this.CycleFocus((mods & .Shift) != 0 ? -1 : 1);
			return true;
		}
		return this.mFocus != null;
	}

	public bool HandleKeyUp(KeyCode key, KeyModifiers mods)
	{
		Widget w = this.mFocus;
		while (w != null && w != this)
		{
			KeyEventArgs args = default;
			args.mKey = key;
			args.mModifiers = mods;
			w.OnKeyUp(ref args);
			if (args.bHandled)
				return true;
			w = w.mParent;
		}
		return this.mFocus != null;
	}

	public bool HandleTextInput(char32 c)
	{
		if (this.mFocus == null)
			return false;
		this.mFocus.OnTextInput(c);
		return true;
	}

	void CollectFocusable(Widget widget, List<Widget> list)
	{
		if (!widget.bVisible || !widget.bEnabled)
			return;
		if (widget.bFocusable)
			list.Add(widget);
		for (let child in widget.mChildren)
			this.CollectFocusable(child, list);
	}

	void CycleFocus(int direction)
	{
		let list = scope List<Widget>();
		this.CollectFocusable(this, list);
		if (list.IsEmpty)
			return;

		var index = this.mFocus != null ? list.IndexOf(this.mFocus) : -1;
		index = (index + direction + list.Count) % list.Count;
		this.SetFocus(list[index]);
	}
}
