namespace Shell.Simulation;

using System;

enum FaultKind
{
	case None;
	case Delay;         // complete later
	case Fail;          // complete with an error
	case Cancel;        // user-cancelled / dismissed
}
