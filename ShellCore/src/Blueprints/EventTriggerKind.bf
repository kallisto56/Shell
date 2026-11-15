namespace Shell.Blueprints;

using System;

enum EventTriggerKind
{
	case Start;             // once, when the instance becomes active
	case Tick;              // every frame, in the Blueprints phase
	case Destroy;           // when the instance is destroyed
	case Custom;            // raised by EmitEvent / by another Blueprint
	case WidgetEvent;       // event of a Widget (source = widget id, event name)
	case GlobalChanged;     // a global variable changed
	case VariableChanged;   // a public variable of another Blueprint changed
}
