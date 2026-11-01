namespace Shell.Animation;

using System;

enum TransitionInterrupt
{
	case None;              // a running transition always completes
	case CurrentState;      // other transitions out of the source state may interrupt
	case NextState;         // transitions out of the target state may interrupt
}
