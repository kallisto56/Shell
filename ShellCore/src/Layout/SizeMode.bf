namespace Shell.Layout;

using System;

enum SizeMode
{
	case Fixed;
	case Auto;          // size to content
	case Fill;          // share of the remaining space (weight in LayoutInfo)
	case Percent;       // percentage of the parent
}
