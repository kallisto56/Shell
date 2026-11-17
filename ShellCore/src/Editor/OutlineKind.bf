namespace Shell.Editor;

using System;

enum OutlineKind
{
	case Widget;
	case Instance;      // UserWidget instance (its content is shown read-only below it)
	case Skin;          // group of a widget's elements
	case Element;
	case Missing;       // instance of a definition that does not exist / would be cyclic
}
