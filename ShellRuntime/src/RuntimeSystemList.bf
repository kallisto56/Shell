namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;

// Registered systems grouped by phase. Order inside a phase: ascending GetOrder(), then registration order.
class RuntimeSystemList
{
	struct Entry
	{
		public IRuntimeSystem mSystem;
		public int mSequence;
	}

	List<Entry> mEntries = new .() ~ delete _;
	List<IRuntimeSystem>[UpdatePhase.cCount] mSorted;
	bool bDirty = true;
	int mNextSequence;

	public this()
	{
		for (int i < UpdatePhase.cCount)
			mSorted[i] = new List<IRuntimeSystem>();
	}

	public ~this()
	{
		for (int i < UpdatePhase.cCount)
			delete mSorted[i];
	}

	public void Add(IRuntimeSystem system)
	{
		Entry entry = default;
		entry.mSystem = system;
		entry.mSequence = mNextSequence++;
		mEntries.Add(entry);
		bDirty = true;
	}

	public bool Remove(IRuntimeSystem system)
	{
		for (int i < mEntries.Count)
		{
			if (mEntries[i].mSystem == system)
			{
				mEntries.RemoveAt(i);
				bDirty = true;
				return true;
			}
		}
		return false;
	}

	public List<IRuntimeSystem> GetPhase(UpdatePhase phase)
	{
		if (bDirty)
			Rebuild();
		return mSorted[(int)phase];
	}

	void Rebuild()
	{
		for (int i < UpdatePhase.cCount)
			mSorted[i].Clear();

		let ordered = scope List<Entry>();
		ordered.AddRange(mEntries);
		ordered.Sort(scope (a, b) =>
		{
			let orderA = a.mSystem.GetOrder();
			let orderB = b.mSystem.GetOrder();
			return (orderA != orderB) ? (orderA <=> orderB) : (a.mSequence <=> b.mSequence);
		});

		for (let entry in ordered)
			mSorted[(int)entry.mSystem.GetPhase()].Add(entry.mSystem);
		bDirty = false;
	}
}
