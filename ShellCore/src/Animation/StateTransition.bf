namespace Shell.Animation;

using System;
using System.Collections;
using Shell.Core;

class StateTransition
{
	public StableId mId;
	public StableId mFrom;                  // none = from any state
	public StableId mTo;
	public List<TransitionCondition> mConditions = new .() ~ delete _;    // all must hold
	public float mDuration;                 // cross-fade seconds
	public bool bHasExitTime;
	public float mExitTime;                 // normalized time of the source state
	public TransitionInterrupt mInterrupt;
}
