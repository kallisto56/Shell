namespace Juno;

using System;
using System.Interop;

enum AddressMode : c_int
{
	case Wrap = 1;
	case Mirror = 2;
	case Clamp = 3;
	case Border = 4;
	case MirrorOnce = 5;
}
