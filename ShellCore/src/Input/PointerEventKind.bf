namespace Shell.Input;

using System;

enum PointerEventKind
{
	case Move;
	case Down;
	case Up;
	case Wheel;
	case Cancel;        // the platform took the pointer away (focus lost, capture stolen)
}
