namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

// Sets (or replaces) a per-instance override: property `property` of the object at `path` inside the instance gets `value` in the
// InstanceOverride layer, whatever the definition or a style says.
class SetOverrideCommand : DefinitionCommand
{
	WidgetNodeData mInstance;
	List<StableId> mPath = new .() ~ delete _;
	StringView mProperty;
	Value mNew;
	Value mOld;
	bool bHadOld;
	OverrideEntry mAdded;               // created on first Apply, owned by the command while it is not in the list
	bool bInList;

	public this(DefinitionEditSession session, WidgetNodeData instance, List<StableId> path, StringView property, Value value) : base(session, "Set override")
	{
		mInstance = instance;
		mPath.AddRange(path);
		mProperty = property;
		mNew = value;
	}

	public ~this()
	{
		if (!bInList)
			delete mAdded;
	}

	OverrideEntry Find()
	{
		for (let entry in mInstance.mOverrides)
		{
			if (entry.mProperty == mProperty && entry.mPath.Count == mPath.Count)
			{
				bool bSame = true;
				for (int i < mPath.Count)
				{
					if (entry.mPath[i] != mPath[i])
						bSame = false;
				}
				if (bSame)
					return entry;
			}
		}
		return null;
	}

	protected override void Apply()
	{
		let existing = Find();
		if (existing != null)
		{
			bHadOld = true;
			mOld = existing.mValue;
			existing.mValue = mNew;
			return;
		}
		bHadOld = false;
		if (mAdded == null)
		{
			mAdded = new OverrideEntry();
			mAdded.mPath.AddRange(mPath);
			mAdded.mProperty = mProperty;
		}
		mAdded.mValue = mNew;
		mInstance.mOverrides.Add(mAdded);
		bInList = true;
	}

	protected override void Revert()
	{
		if (bHadOld)
		{
			let existing = Find();
			if (existing != null)
				existing.mValue = mOld;
			return;
		}
		mInstance.mOverrides.Remove(mAdded);
		bInList = false;
	}
}
