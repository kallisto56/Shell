namespace Shell.Styling;

using System;

// Who is allowed to contribute to a property, in resolution order (later layers are applied on top of earlier ones).
// This is the single arbitration mechanism that keeps styling, animation, Blueprints and solvers from fighting.
enum PropertyLayer
{
	case Default;           // descriptor default
	case Theme;             // token values
	case ComponentStyle;    // base rules of the widget type's style
	case StateStyle;        // state-dependent rules (hover, pressed ...)
	case InstanceOverride;  // per-instance authored value: "the" base value of the instance
	case Animation;         // clips and state machines
	case Blueprint;         // procedural values set by Blueprint nodes (temporary, cleared explicitly)
	case Solver;            // IK / constraints / deformers: topmost, last word

	public const int cCount = 8;
}
