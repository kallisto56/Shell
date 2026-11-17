namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Styling;

// The themes of a project and the active one. Implements IThemeProvider for bindings (StyleToken sources) and answers token lookups
// for the style system.
//
// Lookup: the active theme, then its parent chain (Theme.mParent); a token that is an alias resolves the named token the same way
// (so an alias can be redefined by a derived theme). Cycles in parent chains or aliases fail the lookup instead of looping.
// Change tracking: mEpoch increases whenever the active theme or any token changes; the style system restyles everything when the
// epoch moved. Bindings observe one shared observable (coarse but correct: every StyleToken binding re-evaluates after a theme change).
class ThemeManager : IThemeProvider
{
	const int cMaxChain = 32;

	Dictionary<StableId, Theme> mThemes = new .() ~ delete _;       // not owned
	StableId mActive;
	ObservableValue mChanged = new .() ~ delete _;
	public int mEpoch;

	public void Add(Theme theme)
	{
		mThemes[theme.mId] = theme;
	}

	public Theme Find(StableId id)
	{
		if (mThemes.TryGetValue(id, let theme))
			return theme;
		return null;
	}

	public StableId mActiveId => mActive;
	public Theme mActiveTheme => Find(mActive);

	public bool SetActive(StableId id)
	{
		if (!mThemes.ContainsKey(id))
			return false;
		mActive = id;
		NotifyChanged();
		return true;
	}

	// Call after tokens of a theme were edited.
	public void NotifyChanged()
	{
		mEpoch++;
		mChanged.NotifyChanged();
	}

	Result<Value> Lookup(StringView name, int depth)
	{
		if (depth > cMaxChain)
			return .Err;
		var theme = mActiveTheme;
		for (int hops = 0; theme != null && hops < cMaxChain; hops++)
		{
			let token = theme.FindToken(name);
			if (token != null)
			{
				if (!token.mAlias.IsEmpty)
					return Lookup(token.mAlias, depth + 1);
				return .Ok(token.mValue);
			}
			theme = Find(theme.mParent);
		}
		return .Err;
	}

	public Result<Value> GetToken(StringView name) => Lookup(name, 0);
	public IObservable ObserveToken(StringView name) => mChanged;
}
