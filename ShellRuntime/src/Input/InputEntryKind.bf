namespace Shell.Runtime;

using System;

enum InputEntryKind
{
	case Pointer;
	case Key;
	case Text;
	case Cancel;        // pointer taken away (window deactivated, capture lost)
}
