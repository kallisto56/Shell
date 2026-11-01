namespace Shell.Composition;

using System;
using Shell.Core;

// A property assignment stored in a definition. Only properties that differ from the descriptor default are stored.
struct PropertyValueData
{
	public StringView mName;
	public Value mValue;
}
