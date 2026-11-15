namespace Juno;

using System;
using System.Interop;

enum CullMode : c_int
{
	case None = 1;
	case Front = 2;
	case Back = 3;
}
