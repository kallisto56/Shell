namespace Shell.Simulation;

using System;

enum PowerAction
{
	case None;
	case Shutdown;
	case Restart;
	case Lock;
	case SignOut;
}
