namespace Shell.Styling;

using System;
using Shell.Core;

// Named, typed design value ("color.accent", "radius.control", "font.body.size"). Components refer to tokens instead
// of literals, so a theme change restyles everything. A token may alias another token.
class DesignToken
{
	public StableId mId;
	public String mName = new .() ~ delete _;
	public ValueKind mKind;
	public Value mValue;
	public String mAlias = new .() ~ delete _;      // non-empty: resolve to the token with this name instead
}
