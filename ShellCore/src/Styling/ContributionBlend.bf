namespace Shell.Styling;

using System;

enum ContributionBlend
{
	case Replace;       // value replaces (or lerps towards, by weight) the result so far
	case Add;           // value * weight is added
	case Multiply;      // result is multiplied by lerp(1, value, weight)
}
