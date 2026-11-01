namespace Shell.Blueprints;

using System;

// Closed set of node kinds. Library nodes (math, string, comparison ...) use kind Operator + a type name.
enum NodeKind
{
	// Entry points
	case Event;             // starts an execution chain (see EventTriggerKind)
	case FunctionEntry;
	case FunctionReturn;
	// Flow control
	case Branch;            // bool -> True / False
	case Sequence;
	case Loop;              // for-each over a count (bounded by BlueprintLimits)
	case Delay;             // latent: continues on a later frame
	// Data
	case GetVariable;
	case SetVariable;
	case GetGlobal;
	case SetGlobal;
	case Literal;
	case Operator;          // math / logic / string / comparison library node (mTypeName selects it)
	// Interaction with other systems
	case GetProperty;       // Widget / Element / UserWidget property (typed through its descriptor)
	case SetProperty;
	case CallMethod;        // method of a Widget or runtime object (typed through its MethodDescriptor)
	case CallBlueprint;     // public function of another Blueprint instance (BlueprintRef)
	case EmitEvent;         // public event of this Blueprint
	case CreateObject;      // create a Widget / UserWidget instance / Element
	case DestroyObject;
	case SetAnimationInput; // bool / number / trigger input of a state machine
}
