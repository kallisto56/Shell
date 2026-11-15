namespace Shell.Elements;

using System;

enum EffectKind
{
	case Blur;
	case DropShadow;
	case Glow;
	case ColorMatrix;
	case Custom;        // named shader effect with generic parameters
}
