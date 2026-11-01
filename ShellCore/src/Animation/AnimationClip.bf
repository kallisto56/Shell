namespace Shell.Animation;

using System;
using System.Collections;
using Shell.Core;

// Reusable keyframe animation. Clips are referenced by id from timelines, state machines and Blueprints.
class AnimationClip
{
	public StableId mId;
	public String mName = new .() ~ delete _;
	public float mDuration;
	public bool bLoop;
	public List<AnimationTrack> mTracks = new .() ~ DeleteContainerAndItems!(_);
	public List<AnimationEvent> mEvents = new .() ~ delete _;
}
