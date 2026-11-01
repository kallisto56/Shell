namespace Shell.Binding;

using System;

enum TimeBuiltin
{
	case Time;              // scaled seconds since start
	case UnscaledTime;
	case DeltaTime;         // scaled seconds of the last frame
	case UnscaledDeltaTime;
}
