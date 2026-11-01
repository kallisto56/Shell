namespace Shell.Reflection;

using System;

enum PropertyError
{
	case UnknownProperty;
	case ReadOnly;
	case TypeMismatch;
	case Rejected;      // the owner refused the value (validation)
}
