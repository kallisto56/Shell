namespace Juno;

using System;

// Coordinates are local to the widget that receives the event.
struct MouseEventArgs
{
	public float mX;
	public float mY;
	public MouseButton mButton;
	public int32 mClickCount;       // 1 = single click, 2 = double click, ...
	public KeyModifiers mModifiers;
	public float mWheelX;
	public float mWheelY;
	public bool bHandled;           // Set to true by a handler to stop further routing.
}
