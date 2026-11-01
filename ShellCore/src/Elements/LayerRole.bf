namespace Shell.Elements;

using System;

enum LayerRole
{
	case Underlay;      // background, hover glow
	case Content;       // the Widget's main content (essential: always present)
	case Overlay;       // borders, caret, focus ring
	case Custom;
}
