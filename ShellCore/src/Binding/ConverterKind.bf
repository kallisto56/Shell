namespace Shell.Binding;

using System;

// Closed set of value converters. Deliberately not a scripting language: anything more complex belongs in a Blueprint.
enum ConverterKind
{
	case Not;               // bool -> bool
	case Negate;            // number -> number
	case Scale;             // number * arg0
	case Offset;            // number + arg0
	case Clamp;             // number clamped to [arg0, arg1]
	case IsEmpty;           // string / none -> bool
	case ToText;            // any -> string (invariant formatting)
	case Select;            // bool -> arg0 when true, arg1 when false
	case EqualsTo;          // any -> bool (value == arg0)
	case GreaterThan;       // number -> bool (value > arg0)
	case Coalesce;          // none -> arg0, otherwise unchanged
}
