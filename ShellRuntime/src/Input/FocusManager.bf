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

// Keyboard focus: which widget receives key and text input, focus changes with reasons, Tab / arrow navigation inside focus
// scopes, and the hand-over to the text input service (IME) when the focused widget edits text.
//
// Focus rules: a widget can be focused when it is alive, Focusable, effectively enabled and effectively visible. Destroying
// the focused widget clears focus without callbacks (the widget is going away); hiding or disabling it is handled by
// ValidateFocus(), which the router calls every frame.
class FocusManager : IObjectDestroyListener
{
	RuntimeContext mContext;
	WidgetHost mHost;
	public Handle mFocus;
	ITextInputClient mAttached;

	public this(RuntimeContext context, WidgetHost host)
	{
		mContext = context;
		mHost = host;
		context.AddDestroyListener(this);
	}

	public ~this()
	{
		mContext.RemoveDestroyListener(this);
	}

	public Widget mFocused => mContext.Resolve<Widget>(mFocus);

	static public bool CanFocus(Widget widget)
	{
		return widget.mIsAlive && widget.mProperties.Get(WidgetTypes.sFocusable).AsBool() && widget.mIsEffectivelyEnabled && widget.mIsEffectivelyVisible;
	}

	// The widget itself or the nearest ancestor that can take focus.
	public Widget FindFocusable(Widget widget)
	{
		for (var w = widget; w != null; w = w.mParent)
		{
			if (CanFocus(w))
				return w;
		}
		return null;
	}

	public bool SetFocus(Widget widget, FocusReason reason)
	{
		if (widget == null)
		{
			Clear();
			return true;
		}
		if (!CanFocus(widget))
			return false;

		let current = mFocused;
		if (current == widget)
		{
			if (reason == .Keyboard)
				widget.SetFocusState(true, true);
			return true;
		}

		Clear();
		mFocus = widget.mHandle;
		widget.SetFocusState(true, reason == .Keyboard);
		AttachTextInput(widget);
		widget.OnFocusGained(reason);
		return true;
	}

	public void Clear()
	{
		let current = mFocused;
		mFocus = Handle.sNone;
		if (current == null)
			return;
		DetachTextInput();
		current.SetFocusState(false, false);
		current.OnFocusLost();
	}

	void AttachTextInput(Widget widget)
	{
		let client = widget as ITextInputClient;
		let service = mHost.GetTextInput();
		if (client != null && service != null)
		{
			service.Attach(client);
			mAttached = client;
		}
	}

	void DetachTextInput()
	{
		let service = mHost.GetTextInput();
		if (mAttached != null && service != null)
			service.Detach(mAttached);
		mAttached = null;
	}

	public void OnObjectDestroying(RuntimeObject object)
	{
		if (object.mHandle == mFocus)
		{
			DetachTextInput();
			mFocus = Handle.sNone;
		}
	}

	// Focus must not stay on a widget that became hidden, disabled or unfocusable.
	public void ValidateFocus()
	{
		let current = mFocused;
		if (current != null && !CanFocus(current))
			Clear();
	}

	// ---- Navigation ----

	static Widget FindScope(Widget from)
	{
		var w = from;
		while (w != null)
		{
			if (w.mProperties.Get(WidgetTypes.sFocusScope).AsBool() || w.mParent == null)
				return w;
			w = w.mParent;
		}
		return from;
	}

	static void Collect(Widget widget, Widget scopeRoot, bool tabOnly, List<Widget> output)
	{
		if (!widget.mIsAlive || !widget.mProperties.Get(WidgetTypes.sVisible).AsBool(true) || !widget.mProperties.Get(WidgetTypes.sEnabled).AsBool(true))
			return;
		if (CanFocus(widget) && (!tabOnly || widget.mProperties.Get(WidgetTypes.sTabIndex).AsInt() >= 0))
			output.Add(widget);
		// A nested focus scope is entered as a unit: its content belongs to its own Tab cycle.
		if (widget != scopeRoot && widget.mProperties.Get(WidgetTypes.sFocusScope).AsBool())
			return;
		for (let child in widget.mChildren)
			Collect(child, scopeRoot, tabOnly, output);
	}

	public bool Move(FocusDirection direction, Widget root)
	{
		let current = mFocused;
		let scopeRoot = (current != null) ? FindScope(current) : root;
		if (scopeRoot == null)
			return false;

		if (direction == .Next || direction == .Previous)
			return MoveTab(direction == .Next, scopeRoot, current);
		return MoveDirectional(direction, scopeRoot, current);
	}

	bool MoveTab(bool forward, Widget scopeRoot, Widget current)
	{
		let found = scope List<Widget>();
		Collect(scopeRoot, scopeRoot, true, found);
		if (found.Count == 0)
			return false;

		// Ascending TabIndex, ties in tree order.
		let ordered = scope List<(int tab, int order, Widget widget)>();
		for (int i < found.Count)
			ordered.Add(((int)found[i].mProperties.Get(WidgetTypes.sTabIndex).AsInt(), i, found[i]));
		ordered.Sort(scope (a, b) => (a.tab != b.tab) ? (a.tab <=> b.tab) : (a.order <=> b.order));

		var index = -1;
		for (int i < ordered.Count)
		{
			if (ordered[i].widget == current)
				index = i;
		}
		if (index < 0)
			index = forward ? -1 : 0;
		index = (index + (forward ? 1 : -1) + ordered.Count) % ordered.Count;
		return SetFocus(ordered[index].widget, .Keyboard);
	}

	bool MoveDirectional(FocusDirection direction, Widget scopeRoot, Widget current)
	{
		let found = scope List<Widget>();
		Collect(scopeRoot, scopeRoot, false, found);
		if (found.Count == 0)
			return false;
		if (current == null)
			return SetFocus(found[0], .Keyboard);

		let origin = current.GetRootBounds();
		let ox = origin.mX + origin.mWidth * 0.5f;
		let oy = origin.mY + origin.mHeight * 0.5f;

		Widget best = null;
		float bestScore = float.MaxValue;
		for (let candidate in found)
		{
			if (candidate == current)
				continue;
			let b = candidate.GetRootBounds();
			let dx = b.mX + b.mWidth * 0.5f - ox;
			let dy = b.mY + b.mHeight * 0.5f - oy;

			float primary;
			float secondary;
			switch (direction)
			{
			case .Right: primary = dx; secondary = dy;
			case .Left: primary = -dx; secondary = dy;
			case .Down: primary = dy; secondary = dx;
			case .Up: primary = -dy; secondary = dx;
			default: continue;
			}
			if (primary <= 0)
				continue;

			let score = primary + 2.0f * Math.Abs(secondary);
			if (score < bestScore)
			{
				bestScore = score;
				best = candidate;
			}
		}
		return (best != null) && SetFocus(best, .Keyboard);
	}
}
