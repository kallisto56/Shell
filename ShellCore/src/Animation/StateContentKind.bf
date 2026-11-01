namespace Shell.Animation;

using System;

enum StateContentKind
{
	case Clip;
	case BlendTree;
	case Empty;         // no animation: the state only exists to coordinate behavior
}
