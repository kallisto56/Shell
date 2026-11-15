namespace Shell.Animation;

using System;

enum BlendTreeKind
{
	case Blend1D;       // blend along one number input
	case Blend2D;
	case Additive;      // layer on top of a base clip
}
