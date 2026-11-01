namespace Shell.Elements;

using System;

// How an element and its same-layer descendants are composited.
enum CompositeMode
{
	case None;              // drawn directly into the parent surface
	case IsolatedGroup;     // rendered into an off-screen surface first; effects/opacity apply to the group result
	case BackdropGroup;     // effects apply to what is already drawn behind the element (blur-behind, acrylic)
}
