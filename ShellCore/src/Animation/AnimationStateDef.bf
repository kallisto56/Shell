namespace Shell.Animation;

using System;
using System.Collections;
using Shell.Core;

class AnimationStateDef
{
	public StableId mId;
	public String mName = new .() ~ delete _;
	public StateContentKind mContent;
	public StableId mContentId;             // clip or blend tree
	public float mSpeed = 1;
	public float mX;                        // editor position
	public float mY;
	public List<StringView> mEnterEvents = new .() ~ delete _;    // names raised for Blueprints when the state is entered
}
