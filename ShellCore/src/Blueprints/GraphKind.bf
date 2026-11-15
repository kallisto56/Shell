namespace Shell.Blueprints;

using System;

enum GraphKind
{
	case EventGraph;    // contains Event nodes; one per Blueprint is enough, more are allowed for organization
	case Function;      // has FunctionEntry / FunctionReturn, signature in BlueprintInterface or private
}
