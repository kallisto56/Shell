namespace Shell.Simulation;

using System;

struct FaultDecision
{
	public FaultKind mKind;
	public float mDelaySeconds;
	public StringView mErrorCode;
	public StringView mErrorMessage;
}
