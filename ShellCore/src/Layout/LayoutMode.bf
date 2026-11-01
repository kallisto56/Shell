namespace Shell.Layout;

using System;

enum LayoutMode
{
	case Absolute;      // children placed by their own position / size
	case Stack;         // one row or column (Axis), with spacing
	case Grid;          // rows and columns, cells addressed per child
	case Anchor;        // children anchored to edges / center of the parent with offsets
	case Flow;          // wraps like text
}
