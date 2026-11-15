namespace Shell.Animation;

using System;
using System.Collections;
using Shell.Core;

// Animates one property of one object inside the composition (addressed by stable id, so renames and reordering do
// not break it). Values are written to the Animation contribution layer, never directly to the property.
class AnimationTrack
{
	public StableId mId;
	public StableId mTarget;
	public StringView mProperty;
	public List<Keyframe> mKeys = new .() ~ delete _;       // sorted by time
}
