namespace Juno;

using System;
using System.Interop;

enum ColorWriteMask : c_uchar
{
	case Red = 1;
	case Green = 2;
	case Blue = 4;
	case Alpha = 8;
	case All = 15;
}
