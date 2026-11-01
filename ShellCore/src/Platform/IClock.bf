namespace Shell.Platform;

using System;

// Monotonic and wall-clock time source. The simulation provides a controllable clock (pause, speed up, jump).
interface IClock
{
	double GetMonotonicSeconds();
	int64 GetUtcTicks();
}
