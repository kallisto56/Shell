namespace Shell.Reflection;

using System;

enum CallError
{
	case UnknownMethod;
	case ArgumentCount;
	case ArgumentType;
	case TargetMissing;     // object destroyed / not instantiated
	case Failed;            // the method ran and reported failure
}
