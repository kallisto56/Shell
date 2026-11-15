namespace Juno;

using System;
using System.Interop;

enum ComparisonFunc : c_int
{
	case Never = 1;
	case Less = 2;
	case Equal = 3;
	case LessEqual = 4;
	case Greater = 5;
	case NotEqual = 6;
	case GreaterEqual = 7;
	case Always = 8;
}
