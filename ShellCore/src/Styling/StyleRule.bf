namespace Shell.Styling;

using System;
using System.Collections;
using Shell.Core;
using Shell.Widgets;

class StyleRule
{
	public StableId mId;
	public StyleCondition mCondition;
	public int mPriority;                   // higher wins; equal priority: later declaration wins
	public List<StyleSetter> mSetters = new .() ~ delete _;
}
