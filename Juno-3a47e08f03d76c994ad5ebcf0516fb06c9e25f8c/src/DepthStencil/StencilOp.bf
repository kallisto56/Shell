namespace Juno;

using System;
using System.Interop;

enum StencilOp : c_int
{
	case Keep = 1;
	case Zero = 2;
	case Replace = 3;
	case IncrSat = 4;
	case DecrSat = 5;
	case Invert = 6;
	case Incr = 7;
	case Decr = 8;
}
