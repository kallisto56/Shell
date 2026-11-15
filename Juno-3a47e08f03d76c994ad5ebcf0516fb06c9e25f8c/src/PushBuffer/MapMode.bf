namespace Juno;

using System;
using System.Interop;

enum MapMode : c_int
{
	case Read = 1;
	case Write = 2;
	case ReadWrite = 3;
	case WriteDiscard = 4;
	case WriteNoOverwrite = 5;
}
