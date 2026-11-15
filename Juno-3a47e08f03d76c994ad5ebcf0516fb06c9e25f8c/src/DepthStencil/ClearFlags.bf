namespace Juno;

using System;
using System.Interop;

enum ClearFlags : c_uint
{
	case Depth = 0x1;
	case Stencil = 0x2;
}
