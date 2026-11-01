namespace Shell.Reflection;

using System;

// Distinguishes what a property is, so the editor, bindings and Blueprints treat it correctly.
enum PropertyKind
{
	case State;     // read-only, changed only by the owning runtime object (Hovered, Pressed, CaretRect ...)
	case Value;     // writable and normally serialized (Text, Enabled, Bounds ...)
	case Computed;  // read-only, derived from other values (Length of Text, IsEmpty ...); never serialized
}
