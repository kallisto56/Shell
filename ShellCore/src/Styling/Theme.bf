namespace Shell.Styling;

using System;
using System.Collections;
using Shell.Core;
using Shell.Widgets;

class Theme
{
	public StableId mId;
	public String mName = new .() ~ delete _;
	public StableId mParent;                // fallback theme for tokens that are not defined here
	public List<DesignToken> mTokens = new .() ~ DeleteContainerAndItems!(_);

	public DesignToken FindToken(StringView name)
	{
		for (let token in mTokens)
		{
			if (token.mName == name)
				return token;
		}
		return null;
	}
}
