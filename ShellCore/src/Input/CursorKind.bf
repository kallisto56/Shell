namespace Shell.Input;

using System;

// Cursor requested by a widget. "Default" lets the widget type choose (a TextBox shows an I-beam).
enum CursorKind
{
	case Default;
	case Arrow;
	case IBeam;
	case Hand;
	case Cross;
	case Wait;
	case SizeAll;
}
