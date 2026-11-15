namespace Shell.Layout;

using System;

enum GridTrackKind
{
	case Fixed;     // "120"
	case Auto;      // "auto": as large as its content
	case Star;      // "*", "2*": share of the remaining space
}
