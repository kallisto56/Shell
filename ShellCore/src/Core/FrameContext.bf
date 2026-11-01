namespace Shell.Core;

using System;

struct FrameContext
{
	public uint64 mFrameIndex;
	public double mTime;                // scaled seconds since start
	public double mUnscaledTime;
	public float mDeltaTime;            // scaled (time scale applied, 0 while paused)
	public float mUnscaledDeltaTime;
	public float mTimeScale;
	public UpdatePhase mPhase;
}
