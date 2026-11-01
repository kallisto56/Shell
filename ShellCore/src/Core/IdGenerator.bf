namespace Shell.Core;

using System;

// SplitMix64. Seedable so tests and imports can produce reproducible ids; the default seed is random.
class IdGenerator
{
	uint64 mState;

	public this()
	{
		let random = scope Random();
		mState = ((uint64)random.NextI32() << 32) ^ (uint64)random.NextI32();
	}

	public this(uint64 seed)
	{
		mState = seed;
	}

	public StableId Next()
	{
		while (true)
		{
			mState += 0x9E3779B97F4A7C15;
			uint64 z = mState;
			z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9;
			z = (z ^ (z >> 27)) * 0x94D049BB133111EB;
			z = z ^ (z >> 31);
			if (z != 0)
				return StableId(z);
		}
	}
}
