namespace Shell.Blueprints;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;

// Authoring-time description of a Blueprint (what is saved). A running Blueprint is an IBlueprintInstance.
class BlueprintAsset
{
	public StableId mId;
	public String mName = new .() ~ delete _;
	public uint32 mRevision;
	public List<BlueprintVariable> mVariables = new .() ~ DeleteContainerAndItems!(_);
	public BlueprintInterface mInterface = new .() ~ delete _;
	public List<Graph> mGraphs = new .() ~ DeleteContainerAndItems!(_);
}
