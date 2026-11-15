namespace Juno;

using System;

struct KeyEventArgs
{
	public KeyCode mKey;
	public KeyModifiers mModifiers;
	public bool bIsRepeat;
	public bool bHandled;
}
