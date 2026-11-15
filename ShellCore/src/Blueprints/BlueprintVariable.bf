namespace Shell.Blueprints;

using System;
using Shell.Core;

class BlueprintVariable
{
	public StableId mId;
	public String mName = new .() ~ delete _;
	public ValueKind mKind;
	public Value mDefault;
	public VariableScope mScope = .Instance;
	public bool bPublic;            // part of the public interface (readable by other Blueprints)
	public bool bExternallyWritable; // other Blueprints may also set it (otherwise read-only from outside)
}
