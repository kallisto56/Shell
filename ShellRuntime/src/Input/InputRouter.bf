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

// Input phase system. Drains the InputEventQueue and routes events to widgets.
//
// Pointer: hover tracking (Entered / Exited, Hovered state on the target and all its ancestors), automatic capture on button
//   press (the target keeps receiving move / up events until all buttons are released), focus on press, tunnel (OnPreviewPointer,
//   root -> target) then bubble (OnPointerDown / Up / Move / Wheel, target -> root) until an event is handled.
// Keyboard: to the focused widget (or the root without focus), tunnel then bubble; unhandled Tab / Shift+Tab move focus, unhandled
//   arrow keys move focus spatially.
// Text: committed text goes to the focused widget.
// Disabled widgets block hit testing but receive no callbacks. Widgets destroyed while hovered or captured are dropped.
// The kernel runs this phase with the traversal guard entered, so handlers that add or remove widgets are deferred to Commit.
class InputRouter : IRuntimeSystem, IObjectDestroyListener
{
	RuntimeContext mContext;
	WidgetHost mHost;
	FocusManager mFocus;
	InputEventQueue mQueue;

	public Handle mRoot;
	List<Handle> mHoverChain = new .() ~ delete _;      // deepest first
	int mButtonsDown;
	float mLastX;
	float mLastY;
	public int mOrder = -500;

	public this(RuntimeContext context, WidgetHost host, FocusManager focus, InputEventQueue queue)
	{
		mContext = context;
		mHost = host;
		mFocus = focus;
		mQueue = queue;
		context.AddDestroyListener(this);
	}

	public ~this()
	{
		mContext.RemoveDestroyListener(this);
	}

	public void SetRoot(Widget root)
	{
		mRoot = root.mHandle;
	}

	public Widget mRootWidget => mContext.Resolve<Widget>(mRoot);

	public UpdatePhase GetPhase() => .Input;
	public int GetOrder() => mOrder;

	public void OnObjectDestroying(RuntimeObject object)
	{
		if (mHost.mCapture == object.mHandle)
			mHost.mCapture = Handle.sNone;
		mHoverChain.Remove(object.mHandle);
	}

	public void Update(FrameContext frame)
	{
		let entries = scope List<InputEntry>();
		mQueue.Drain(entries);
		for (let entry in entries)
		{
			switch (entry.mKind)
			{
			case .Pointer: HandlePointer(entry.mPointer);
			case .Key: HandleKey(entry.mKey);
			case .Text: HandleText(entry.mText);
			case .Cancel: HandleCancel();
			}
			delete entry;
		}
		mFocus.ValidateFocus();
	}

	// ---- helpers ----

	static void BuildChain(Widget target, List<Widget> chain)
	{
		for (var w = target; w != null; w = w.mParent)
			chain.Add(w);       // target first, root last
	}

	static PointerEvent Localize(PointerEvent e, Widget widget)
	{
		var result = e;
		let local = widget.RootToLocal(e.mX, e.mY);
		result.mLocalX = local.mX;
		result.mLocalY = local.mY;
		return result;
	}

	// ---- Pointer ----

	void UpdateHover(float x, float y)
	{
		let root = mRootWidget;
		Widget target = null;
		if (root != null)
			target = root.FindTargetAt(x, y);

		let newChain = scope List<Widget>();
		BuildChain(target, newChain);

		// Exited: in the old chain but not in the new one (deepest first).
		let oldChain = scope List<Handle>();
		oldChain.AddRange(mHoverChain);
		for (let handle in oldChain)
		{
			let widget = mContext.Resolve<Widget>(handle);
			if (widget == null)
				continue;
			if (!newChain.Contains(widget))
			{
				widget.SetHovered(false);
				widget.OnPointerExited();
			}
		}

		// Entered: in the new chain but not in the old one (outermost first).
		for (var i = newChain.Count - 1; i >= 0; i--)
		{
			let widget = newChain[i];
			if (!oldChain.Contains(widget.mHandle))
			{
				widget.SetHovered(true);
				widget.OnPointerEntered();
			}
		}

		mHoverChain.Clear();
		for (let widget in newChain)
			mHoverChain.Add(widget.mHandle);
	}

	Widget mHovered => (mHoverChain.Count > 0) ? mContext.Resolve<Widget>(mHoverChain[0]) : null;

	void Bubble(Widget target, PointerEvent e, PointerEventKind kind)
	{
		var current = e;
		for (var w = target; w != null; w = w.mParent)
		{
			if (!w.mIsAlive || !w.mIsEffectivelyEnabled)
				continue;
			current = Localize(current, w);
			switch (kind)
			{
			case .Down: w.OnPointerDown(ref current);
			case .Up: w.OnPointerUp(ref current);
			case .Move: w.OnPointerMove(ref current);
			case .Wheel: w.OnPointerWheel(ref current);
			case .Cancel:
			}
			if (current.bHandled)
				return;
		}
	}

	// Returns true when a preview handler handled the event.
	bool Tunnel(Widget target, ref PointerEvent e)
	{
		let chain = scope List<Widget>();
		BuildChain(target, chain);
		for (var i = chain.Count - 1; i >= 0; i--)
		{
			let w = chain[i];
			if (!w.mIsAlive || !w.mIsEffectivelyEnabled)
				continue;
			e = Localize(e, w);
			w.OnPreviewPointer(ref e);
			if (e.bHandled)
				return true;
		}
		return false;
	}

	void UpdateCursor()
	{
		var widget = mHost.mCaptureWidget;
		if (widget == null)
			widget = mHovered;
		mHost.mCursor = (widget != null && widget.mIsEffectivelyEnabled) ? widget.mEffectiveCursor : CursorKind.Arrow;
	}

	static int ButtonBit(PointerButton button)
	{
		return (button == .None) ? 0 : (1 << ((int)button - 1));
	}

	void HandlePointer(PointerEvent pointer)
	{
		var e = pointer;
		mLastX = e.mX;
		mLastY = e.mY;
		UpdateHover(e.mX, e.mY);

		switch (e.mKind)
		{
		case .Move:
		{
			let target = (mHost.mCaptureWidget != null) ? mHost.mCaptureWidget : mHovered;
			if (target != null)
				Bubble(target, e, .Move);
		}
		case .Down:
		{
			let target = (mHost.mCaptureWidget != null) ? mHost.mCaptureWidget : mHovered;
			mButtonsDown |= ButtonBit(e.mButton);
			if (target == null)
			{
				mFocus.Clear();
				break;
			}
			if (mHost.mCaptureWidget == null)
				mHost.CapturePointer(target);

			if (Tunnel(target, ref e))
				break;

			// Focus follows the press: the nearest focusable widget, or nothing when the press landed elsewhere.
			let focusable = mFocus.FindFocusable(target);
			if (focusable != null)
				mFocus.SetFocus(focusable, .Pointer);
			else
				mFocus.Clear();
			Bubble(target, e, .Down);
		}
		case .Up:
		{
			let target = (mHost.mCaptureWidget != null) ? mHost.mCaptureWidget : mHovered;
			mButtonsDown &= ~ButtonBit(e.mButton);
			if (target != null)
				Bubble(target, e, .Up);
			if (mButtonsDown == 0)
			{
				mHost.mCapture = Handle.sNone;
				UpdateHover(e.mX, e.mY);
			}
		}
		case .Wheel:
		{
			let target = mHovered;
			if (target != null)
				Bubble(target, e, .Wheel);
		}
		case .Cancel:
			HandleCancel();
		}
		UpdateCursor();
	}

	void HandleCancel()
	{
		let captured = mHost.mCaptureWidget;
		mHost.mCapture = Handle.sNone;
		mButtonsDown = 0;
		if (captured != null)
			captured.OnPointerCancel();
		UpdateCursor();
	}

	// ---- Keyboard / text ----

	void HandleKey(KeyEvent key)
	{
		var e = key;
		let root = mRootWidget;
		let focused = mFocus.mFocused;
		let target = (focused != null) ? focused : root;
		if (target == null)
			return;

		let chain = scope List<Widget>();
		BuildChain(target, chain);

		// Tunnel
		for (var i = chain.Count - 1; i >= 0; i--)
		{
			let w = chain[i];
			if (!w.mIsAlive || !w.mIsEffectivelyEnabled)
				continue;
			w.OnPreviewKey(ref e);
			if (e.bHandled)
				return;
		}
		// Bubble
		for (let w in chain)
		{
			if (!w.mIsAlive || !w.mIsEffectivelyEnabled)
				continue;
			if (e.bIsDown) w.OnKeyDown(ref e);
			else w.OnKeyUp(ref e);
			if (e.bHandled)
				return;
		}

		// Default keyboard navigation.
		if (!e.bIsDown || root == null)
			return;
		let noModifiers = (e.mModifiers & (.Control | .Alt)) == 0;
		switch (e.mKey)
		{
		case .Tab:
			if ((e.mModifiers & .Control) == 0)
				mFocus.Move((e.mModifiers & .Shift) != 0 ? FocusDirection.Previous : FocusDirection.Next, root);
		case .Left:
			if (noModifiers && focused != null) mFocus.Move(.Left, root);
		case .Right:
			if (noModifiers && focused != null) mFocus.Move(.Right, root);
		case .Up:
			if (noModifiers && focused != null) mFocus.Move(.Up, root);
		case .Down:
			if (noModifiers && focused != null) mFocus.Move(.Down, root);
		default:
		}
	}

	void HandleText(StringView text)
	{
		let focused = mFocus.mFocused;
		if (focused == null || !focused.mIsEffectivelyEnabled)
			return;

		TextInputEvent e = default;
		e.mText = text;
		for (var w = focused; w != null; w = w.mParent)
		{
			if (!w.mIsAlive || !w.mIsEffectivelyEnabled)
				continue;
			w.OnTextInput(ref e);
			if (e.bHandled)
				return;
		}
	}
}
