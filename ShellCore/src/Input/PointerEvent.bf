namespace Shell.Input;

using System;

// Position is in root (window client) coordinates; mLocalX/mLocalY are filled in by the router for each receiving widget.
struct PointerEvent
{
	public PointerEventKind mKind;
	public float mX;
	public float mY;
	public float mLocalX;
	public float mLocalY;
	public PointerButton mButton;
	public int32 mClickCount;           // 1 single, 2 double, 3 triple ...
	public KeyModifiers mModifiers;
	public float mWheelX;               // notches (positive = right / away from the user)
	public float mWheelY;
	public bool bHandled;               // set by a handler to stop routing
}
