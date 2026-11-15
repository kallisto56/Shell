namespace Shell.Input;

using System;

enum FocusDirection
{
	case Next;          // Tab
	case Previous;      // Shift+Tab
	case Up;
	case Down;
	case Left;
	case Right;
}
