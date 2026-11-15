namespace Shell.Blueprints;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;

// The explicit public surface of a Blueprint. Other Blueprints, Widgets and the editor can only use what is declared
// here: public variables (by id, they live in BlueprintAsset.mVariables), callable functions, and events.
class BlueprintInterface
{
	public List<StableId> mPublicVariables = new .() ~ delete _;
	public List<FunctionSignature> mFunctions = new .() ~ DeleteContainerAndItems!(_);
	public List<EventSignature> mEvents = new .() ~ DeleteContainerAndItems!(_);
}
