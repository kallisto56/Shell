namespace Shell.Input;

using System;

enum FocusReason
{
	case Programmatic;
	case Pointer;
	case Keyboard;      // Tab / arrow navigation: shows the keyboard focus ring
}
