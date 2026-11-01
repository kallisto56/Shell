namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;

// Selected objects, by stable id (a selection survives rebuilding the live preview).
class Selection
{
	public List<StableId> mItems = new .() ~ delete _;
	public StableId mPrimary;

	public void Set(StableId id)
	{
		mItems.Clear();
		mItems.Add(id);
		mPrimary = id;
	}

	public void Toggle(StableId id)
	{
		if (!mItems.Remove(id))
		{
			mItems.Add(id);
			mPrimary = id;
		}
	}

	public void Clear()
	{
		mItems.Clear();
		mPrimary = StableId.sNone;
	}

	public bool Contains(StableId id) => mItems.Contains(id);
}
