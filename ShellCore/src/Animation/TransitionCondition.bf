namespace Shell.Animation;

using System;
using Shell.Core;

struct TransitionCondition
{
	public StableId mInput;
	public ConditionOp mOp;
	public Value mOperand;
}
