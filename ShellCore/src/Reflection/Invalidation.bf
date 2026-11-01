namespace Shell.Reflection;

using System;

// What must be recomputed when a property changes. Used for dependency tracking instead of rebuilding everything.
enum Invalidation : uint16
{
	case None = 0;
	case Visual = 1;        // redraw only
	case Layout = 2;        // measure/arrange
	case Geometry = 4;      // regenerate vector geometry / meshes
	case Style = 8;         // re-resolve style rules
	case Structure = 16;    // composition changed (conditional children, instances)
	case Text = 32;         // re-shape text
}
