namespace Shell.Animation;

using System;

// Marker inside a clip that raises an event (for Blueprints / state machines) when playback passes it.
struct AnimationEvent
{
	public float mTime;
	public StringView mName;
}
