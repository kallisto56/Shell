namespace Shell.PlatformWin;

using System;
using Shell.Core;

// Runs in the Input phase before everything else: releases operations of the previous frame and polls the window list.
class WindowsPlatformSystem : IRuntimeSystem
{
	WindowsPlatform mPlatform;
	double mLastPoll = -1;
	public double mPollIntervalSeconds = 0.1;

	public this(WindowsPlatform platform)
	{
		mPlatform = platform;
	}

	public UpdatePhase GetPhase() => .Input;
	public int GetOrder() => -1000;

	public void Update(FrameContext frame)
	{
		mPlatform.mOperations.Prune();
		if (frame.mUnscaledTime - mLastPoll >= mPollIntervalSeconds)
		{
			mLastPoll = frame.mUnscaledTime;
			mPlatform.mWindows.Poll();
		}
	}
}
