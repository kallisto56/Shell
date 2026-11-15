namespace Juno;

using System;
using System.Interop;

enum Usage : c_int
{
	case Default = 0;
	case Immutable = 1;
	case Dynamic = 2;
	case Staging = 3;
}
