namespace Shell.Composition;

using System;

enum ExposedKind
{
	case Property;
	case Variable;      // public variable of an inner Blueprint
	case Method;
	case Event;
}
