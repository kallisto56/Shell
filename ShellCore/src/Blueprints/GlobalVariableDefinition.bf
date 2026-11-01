namespace Shell.Blueprints;

using System;
using Shell.Core;

class GlobalVariableDefinition
{
	public StableId mId;
	public String mName = new .() ~ delete _;
	public ValueKind mKind;
	public Value mInitial;
	public bool bPersistent;
	public String mDescription = new .() ~ delete _;
}
