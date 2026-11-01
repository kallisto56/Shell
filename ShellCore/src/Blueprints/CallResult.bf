namespace Shell.Blueprints;

using System;
using System.Collections;
using Shell.Core;

class CallResult
{
	public CallStatus mStatus;
	public List<Value> mOutputs = new .() ~ delete _;

	public bool mSucceeded => mStatus == .Ok;
}
