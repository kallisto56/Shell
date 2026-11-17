namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

// Removes an override: the object goes back to what the definition and the styles say.
class ClearOverrideCommand : DefinitionCommand
{
	WidgetNodeData mInstance;
	OverrideEntry mEntry;
	int mIndex;
	bool bRemoved;

	public this(DefinitionEditSession session, WidgetNodeData instance, OverrideEntry entry) : base(session, "Clear override")
	{
		mInstance = instance;
		mEntry = entry;
	}

	public ~this()
	{
		if (bRemoved)
			delete mEntry;
	}

	protected override void Apply()
	{
		mIndex = mInstance.mOverrides.IndexOf(mEntry);
		mInstance.mOverrides.Remove(mEntry);
		bRemoved = true;
	}

	protected override void Revert()
	{
		mInstance.mOverrides.Insert(Math.Clamp(mIndex, 0, mInstance.mOverrides.Count), mEntry);
		bRemoved = false;
	}
}
