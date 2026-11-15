namespace Juno;

using System;

enum KeyModifiers : uint8
{
	case None = 0;
	case Shift = 1;
	case Control = 2;
	case Alt = 4;
	case Super = 8;
}
