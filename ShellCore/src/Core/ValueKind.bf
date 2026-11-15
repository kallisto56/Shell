namespace Shell.Core;

using System;

// Closed set of value types that properties, bindings, Blueprint pins, variables and animation tracks can carry.
enum ValueKind : uint8
{
	case None;
	case Bool;
	case Int;
	case Float;
	case String;
	case Vector2;
	case Color;     // r,g,b,a in 0..1, linear storage, sRGB in the editor UI
	case Rect;      // x, y, width, height
	case Id;        // StableId reference to a serializable object
	case Handle;    // runtime-only reference to a live object
	case Enum;      // case name of a named enum type
}
