namespace Shell.Simulation;

using System;

// Scripted behavior of simulated services, e.g. "Delete on paths under /Documents fails with access-denied", or "every
// operation takes 1.5 s". Rules are part of the simulation scenario saved with the project.
class FaultRule
{
	public String mOperation = new .() ~ delete _;      // "files.delete", "files.*", "launcher.launch" ...
	public String mTargetPattern = new .() ~ delete _;  // path / id pattern, empty = any
	public FaultKind mKind;
	public float mDelaySeconds;
	public String mErrorCode = new .() ~ delete _;
	public String mErrorMessage = new .() ~ delete _;
	public float mProbability = 1;                      // evaluated with a seeded generator: scenarios replay identically
}
