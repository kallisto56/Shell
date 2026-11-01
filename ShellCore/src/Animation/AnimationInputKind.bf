namespace Shell.Animation;

using System;

enum AnimationInputKind
{
	case Bool;
	case Number;
	case Trigger;       // set by a caller, consumed by the first transition that uses it
}
