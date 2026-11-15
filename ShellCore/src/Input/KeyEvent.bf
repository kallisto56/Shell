namespace Shell.Input;

using System;

struct KeyEvent
{
	public Key mKey;
	public KeyModifiers mModifiers;
	public bool bIsDown;
	public bool bIsRepeat;
	public bool bHandled;
}
