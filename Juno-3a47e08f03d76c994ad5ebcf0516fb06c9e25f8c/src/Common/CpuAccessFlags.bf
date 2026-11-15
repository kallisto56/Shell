namespace Juno;

using System;
using System.Interop;

enum CpuAccessFlags : c_uint
{
	case None = 0;
	case Write = 0x10000;
	case Read = 0x20000;
}
