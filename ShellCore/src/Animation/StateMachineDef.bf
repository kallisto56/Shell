namespace Shell.Animation;

using System;
using System.Collections;
using Shell.Core;

// Selects and coordinates authored animation. It decides *which* clip or blend runs and when to switch; it does not
// contain general application logic (that is Blueprint's job) and does not compute procedural deformation (rig solvers).
class StateMachineDef
{
	public StableId mId;
	public String mName = new .() ~ delete _;
	public StableId mEntryState;
	public List<AnimationInputDef> mInputs = new .() ~ DeleteContainerAndItems!(_);
	public List<AnimationStateDef> mStates = new .() ~ DeleteContainerAndItems!(_);
	public List<StateTransition> mTransitions = new .() ~ DeleteContainerAndItems!(_);
	public List<BlendTreeDef> mBlendTrees = new .() ~ DeleteContainerAndItems!(_);
}
