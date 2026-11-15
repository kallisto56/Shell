namespace Juno;

using System;

// How a child follows its parent when the parent is resized (WinForms style).
//   Left|Top        : stays where it is (default)
//   Right|Bottom    : keeps its distance to the right/bottom edge
//   Left|Right      : stretches horizontally (same for Top|Bottom vertically)
enum Anchor : uint8
{
	case None = 0;
	case Left = 1;
	case Top = 2;
	case Right = 4;
	case Bottom = 8;
	case All = 15;
}
