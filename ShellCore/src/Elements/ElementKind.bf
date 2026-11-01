namespace Shell.Elements;

using System;

enum ElementKind
{
	case Container;     // groups children, carries transform / clip / layout
	case Shape;         // rectangle, rounded rectangle, ellipse ...
	case Path;          // vector geometry (fill, stroke, boolean ops later)
	case Text;          // shaped text (HarfBuzz) with selection / caret decorations
	case Image;
	case Video;
	case Mesh;          // reserved: weighted geometry for skeleton deformation (not implemented yet)
}
