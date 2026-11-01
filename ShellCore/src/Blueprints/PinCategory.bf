namespace Shell.Blueprints;

using System;

enum PinCategory
{
	case Exec;      // execution flow (white wires)
	case Data;      // typed value
}
