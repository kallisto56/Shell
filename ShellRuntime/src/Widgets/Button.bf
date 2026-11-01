namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Widgets;
using Shell.Input;
using Shell.Text;
using Shell.Platform;

// Push button. Pointer: press (captured by the router) -> Pressed while the pointer is inside -> release inside raises Clicked
// (ClickMode Press raises on press instead). Keyboard: Space raises on release, Enter on press. Disabled buttons do nothing.
// The widget has no visuals: a skin binds to Text, Hovered, Pressed, Focused, KeyboardFocused and IsEffectivelyEnabled.
class Button : Widget
{
	static public TypeDescriptor sType;
	static public PropertyDescriptor sText;
	static public PropertyDescriptor sClickMode;      // Release (default) | Press
	static public EventDescriptor sClicked;
	static public MethodDescriptor sClick;

	bool bPointerPressed;
	bool bKeyPressed;

	static public bool Register(RuntimeContext context)
	{
		if (sType == null)
		{
			let b = new WidgetTypeBuilder("Button", WidgetTypes.sWidget);
			sText = b.AddValue("Text", .String, default, .Layout | .Text | .Visual);
			sClickMode = b.AddValue("ClickMode", .Enum, Value.FromEnum("Release"), .None, .Serialized | .Bindable, "ClickMode");
			sClicked = b.AddEvent("Clicked");
			sClick = b.AddMethod("Click");
			sType = b.mType;
			sType.OverrideDefault(WidgetTypes.sFocusable, Value.FromBool(true));
			delete b;
		}
		return context.mTypes.Register(sType, context.mDiagnostics, false);
	}

	public override TypeDescriptor GetDescriptor() => sType;

	bool mClickOnPress => mProperties.Get(sClickMode).AsString() == "Press";

	// Programmatic click (also what the Click method does). Ignored while disabled.
	public void Click()
	{
		if (mIsEffectivelyEnabled)
			RaiseEvent(sClicked);
	}

	protected override Result<Value, CallError> OnInvokeMethod(MethodDescriptor method, List<Value> arguments)
	{
		if (method == sClick)
		{
			Click();
			return .Ok(Value.sNone);
		}
		return base.OnInvokeMethod(method, arguments);
	}

	public override void OnPointerDown(ref PointerEvent e)
	{
		if (e.mButton != .Left)
			return;
		bPointerPressed = true;
		SetPressed(true);
		if (mClickOnPress)
			Click();
		e.bHandled = true;
	}

	public override void OnPointerMove(ref PointerEvent e)
	{
		if (bPointerPressed)
			SetPressed(HitTest(e.mLocalX, e.mLocalY));      // pressed only while the pointer is over the button
	}

	public override void OnPointerUp(ref PointerEvent e)
	{
		if (e.mButton != .Left || !bPointerPressed)
			return;
		bPointerPressed = false;
		let inside = HitTest(e.mLocalX, e.mLocalY);
		SetPressed(false);
		if (inside && !mClickOnPress)
			Click();
		e.bHandled = true;
	}

	public override void OnPointerCancel()
	{
		bPointerPressed = false;
		SetPressed(bKeyPressed);
	}

	public override void OnKeyDown(ref KeyEvent e)
	{
		if (e.bIsRepeat)
			return;
		if (e.mKey == .Space)
		{
			bKeyPressed = true;
			SetPressed(true);
			e.bHandled = true;
		}
		else if (e.mKey == .Enter)
		{
			Click();
			e.bHandled = true;
		}
	}

	public override void OnKeyUp(ref KeyEvent e)
	{
		if (e.mKey == .Space && bKeyPressed)
		{
			bKeyPressed = false;
			SetPressed(bPointerPressed);
			Click();
			e.bHandled = true;
		}
	}

	public override void OnFocusLost()
	{
		base.OnFocusLost();
		if (bKeyPressed)
		{
			bKeyPressed = false;
			SetPressed(bPointerPressed);
		}
	}
}
