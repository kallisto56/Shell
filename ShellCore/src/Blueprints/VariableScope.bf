namespace Shell.Blueprints;

using System;

enum VariableScope
{
	case Local;         // inside one function call; created on entry, gone on return
	case Instance;      // one per Blueprint instance
	case Persistent;    // like Instance, but stored by the persistence service between sessions
}
