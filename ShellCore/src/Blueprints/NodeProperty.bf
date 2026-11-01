namespace Shell.Blueprints;

using System;
using Shell.Core;

// Named constant parameter of a node (event trigger kind, variable name, property name, operator options ...).
struct NodeProperty
{
	public StringView mName;
	public Value mValue;
}
