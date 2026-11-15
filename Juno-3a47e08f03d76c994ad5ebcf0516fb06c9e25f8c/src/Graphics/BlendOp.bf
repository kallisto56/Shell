namespace Juno;

using System;
using System.Interop;

enum BlendOp : c_int
{
	case Add = 1;
	case Subtract = 2;
	case RevSubtract = 3;
	case Min = 4;
	case Max = 5;
}
