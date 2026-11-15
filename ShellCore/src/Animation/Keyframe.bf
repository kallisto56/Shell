namespace Shell.Animation;

using System;
using Shell.Core;

struct Keyframe
{
	public float mTime;                     // seconds from the start of the clip
	public Value mValue;
	public InterpolationKind mInterpolation;    // how to get from this key to the next
	public float mInTangent;                // Bezier handles (normalized time/value deltas)
	public float mOutTangent;
}
