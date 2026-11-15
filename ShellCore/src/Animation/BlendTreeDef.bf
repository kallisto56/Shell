namespace Shell.Animation;

using System;
using System.Collections;
using Shell.Core;

class BlendTreeDef
{
	public StableId mId;
	public String mName = new .() ~ delete _;
	public BlendTreeKind mKind;
	public StableId mInputX;
	public StableId mInputY;
	public List<BlendTreeEntry> mEntries = new .() ~ delete _;
}
