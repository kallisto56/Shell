namespace Shell.Elements;

using System;

enum RenderItemKind
{
	case Draw;          // draw one element's own content
	case BeginGroup;    // start of an isolated / backdrop group
	case EndGroup;
}
