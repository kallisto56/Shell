namespace Shell.Core;

using System;
using System.Collections;

// Interns strings so that Value (a plain struct) can refer to text without owning it.
//
//   Intern()          permanent entries (names from files, descriptor defaults, enum case names). Never freed.
//   InternTransient() collectible entries for text that changes at run time (a TextBox's Text, bound strings).
//                     An entry lives as long as at least one property slot holds it (PropertyStore retains / releases)
//                     and is freed by CollectGarbage() (Commit phase) once nothing refers to it any more.
//
// Freeing is deferred to the Commit phase on purpose: during a frame, bindings and caches may still hold the old view
// of a string whose property just changed; they refresh in the Bindings phase, which runs before Commit.
// Views of strings that are not in the pool (string literals) are valid forever and ignored by Retain/Release.
class StringPool
{
	class Entry
	{
		public String mText ~ delete _;
		public int mRefs;
		public bool bPermanent;
		public bool bPending;
	}

	Dictionary<String, Entry> mMap = new .() ~ delete _;    // key aliases Entry.mText
	List<Entry> mPending = new .() ~ delete _;

	public ~this()
	{
		for (let entry in mMap)
			delete entry.value;
	}

	public int mCount => mMap.Count;

	Entry Find(StringView text)
	{
		let probe = scope String(text);
		if (mMap.TryGetValue(probe, let entry))
			return entry;
		return null;
	}

	Entry Create(StringView text)
	{
		let entry = new Entry();
		entry.mText = new String(text);
		mMap[entry.mText] = entry;
		return entry;
	}

	public StringView Intern(StringView text)
	{
		if (text.IsEmpty)
			return default;
		var entry = Find(text);
		if (entry == null)
			entry = Create(text);
		entry.bPermanent = true;
		return entry.mText;
	}

	public StringView InternTransient(StringView text)
	{
		if (text.IsEmpty)
			return default;
		var entry = Find(text);
		if (entry == null)
			entry = Create(text);
		if (!entry.bPermanent && entry.mRefs == 0 && !entry.bPending)
		{
			entry.bPending = true;      // collected unless somebody retains it before the next CollectGarbage
			mPending.Add(entry);
		}
		return entry.mText;
	}

	public void Retain(StringView text)
	{
		if (text.IsEmpty)
			return;
		let entry = Find(text);
		if (entry != null)
			entry.mRefs++;
	}

	public void Release(StringView text)
	{
		if (text.IsEmpty)
			return;
		let entry = Find(text);
		if (entry == null)
			return;
		entry.mRefs--;
		if (entry.mRefs <= 0 && !entry.bPermanent && !entry.bPending)
		{
			entry.bPending = true;
			mPending.Add(entry);
		}
	}

	// Commit phase. Frees collectible entries that nobody retains.
	public int CollectGarbage()
	{
		int freed = 0;
		for (let entry in mPending)
		{
			entry.bPending = false;
			if (entry.mRefs <= 0 && !entry.bPermanent)
			{
				mMap.Remove(entry.mText);
				delete entry;
				freed++;
			}
		}
		mPending.Clear();
		return freed;
	}
}
