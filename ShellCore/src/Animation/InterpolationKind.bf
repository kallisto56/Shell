namespace Shell.Animation;

using System;

enum InterpolationKind
{
	case Step;
	case Linear;
	case Bezier;        // cubic, uses the keyframe tangents
	case EaseIn;
	case EaseOut;
	case EaseInOut;
}
