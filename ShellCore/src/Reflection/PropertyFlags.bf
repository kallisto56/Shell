namespace Shell.Reflection;

using System;

enum PropertyFlags : uint16
{
	case None = 0;
	case Animatable = 1;    // can be targeted by animation tracks
	case Serialized = 2;    // written to the saved format (default for Value properties)
	case Bindable = 4;      // can be the source or target of a binding
	case Hidden = 8;        // not shown in the inspector
	case Styleable = 16;    // can be set by style rules and tokens
}
