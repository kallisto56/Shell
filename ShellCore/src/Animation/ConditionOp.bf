namespace Shell.Animation;

using System;

enum ConditionOp
{
	case IsTrue;
	case IsFalse;
	case Equals;
	case NotEquals;
	case Greater;
	case Less;
	case Triggered;
}
