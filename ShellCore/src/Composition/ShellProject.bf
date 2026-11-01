namespace Shell.Composition;

using System;
using System.Collections;
using Shell.Core;
using Shell.Blueprints;
using Shell.Styling;
using Shell.Serialization;

// Root of everything that is saved in one file: manifest, global variable definitions, themes, component styles,
// UserWidget definitions and shared (project level) Blueprints. Strings referenced by StringView inside the model are
// interned in mStrings, so the project owns every piece of text it points at.
class ShellProject
{
	public StringPool mStrings = new .() ~ delete _;
	public PackageManifest mManifest = new .() ~ delete _;
	public StableId mEntryComposition;      // composition instantiated as the shell / preview root (may be none)
	public List<GlobalVariableDefinition> mGlobals = new .() ~ DeleteContainerAndItems!(_);
	public List<Theme> mThemes = new .() ~ DeleteContainerAndItems!(_);
	public List<ComponentStyle> mStyles = new .() ~ DeleteContainerAndItems!(_);
	public List<BlueprintAsset> mBlueprints = new .() ~ DeleteContainerAndItems!(_);   // shared / singleton Blueprints
	public CompositionRegistry mCompositions = new .() ~ delete _;

	public Theme FindTheme(StableId id)
	{
		for (let theme in mThemes)
		{
			if (theme.mId == id)
				return theme;
		}
		return null;
	}
}
