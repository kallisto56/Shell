namespace Shell.Styling;

using System;
using Shell.Core;

struct StyleSetter
{
	public StableId mTarget;                // element inside the widget skin; none = the widget itself
	public StringView mProperty;
	public Value mValue;
	public StringView mToken;               // non-empty: take the value from this design token
}
