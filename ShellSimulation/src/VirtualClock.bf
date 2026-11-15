namespace Shell.Simulation;

using System;
using Shell.Platform;

// Controllable clock. Time only moves when the simulation advances it, so scenarios replay identically.
class VirtualClock : IClock
{
	double mSeconds;
	int64 mStartUtcTicks = 638000000000000000;      // a fixed date, not the host's current time

	public double GetMonotonicSeconds() => mSeconds;
	public int64 GetUtcTicks() => mStartUtcTicks + (int64)(mSeconds * 10000000.0);

	public void Advance(double seconds)
	{
		mSeconds += Math.Max(seconds, 0);
	}

	public void Set(double seconds)
	{
		mSeconds = seconds;
	}
}
