namespace Shell.Styling;

using System;
using System.Collections;
using Shell.Core;
using Shell.Widgets;

// Reusable style of one widget type ("Button"): ordered state-dependent rules. Per-instance overrides are not part of
// the style; they are stored on the instance and applied above it (see PropertyLayer).
class ComponentStyle
{
	public StableId mId;
	public String mName = new .() ~ delete _;
	public StringView mWidgetType;
	public StableId mBaseStyle;             // optional parent style (rules are inherited, then overridden)
	public List<StyleRule> mRules = new .() ~ DeleteContainerAndItems!(_);
}
