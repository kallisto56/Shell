namespace Shell.Core;

using System;
using System.Collections;

// Slot table that maps Handles to objects. It does not own the objects.
class HandleTable<T> where T : class
{
	struct Slot
	{
		public T mObject;
		public uint32 mGeneration;
	}

	List<Slot> mSlots = new .() ~ delete _;
	List<uint32> mFreeList = new .() ~ delete _;
	public int mLiveCount;

	public Handle Allocate(T object)
	{
		uint32 index;
		if (mFreeList.Count > 0)
		{
			index = mFreeList.PopBack();
		}
		else
		{
			Slot slot = default;
			slot.mGeneration = 1;
			mSlots.Add(slot);
			index = (uint32)(mSlots.Count - 1);
		}

		var slot = mSlots[(int)index];
		slot.mObject = object;
		mSlots[(int)index] = slot;
		mLiveCount++;
		return Handle(index, slot.mGeneration);
	}

	// Returns null for invalid, stale or released handles.
	public T Resolve(Handle handle)
	{
		if (!handle.mIsValid || (int)handle.mIndex >= mSlots.Count)
			return null;
		let slot = mSlots[(int)handle.mIndex];
		if (slot.mGeneration != handle.mGeneration)
			return null;
		return slot.mObject;
	}

	public bool Release(Handle handle)
	{
		if (Resolve(handle) == null)
			return false;

		var slot = mSlots[(int)handle.mIndex];
		slot.mObject = null;
		slot.mGeneration++;
		if (slot.mGeneration == 0)
			slot.mGeneration = 1;
		mSlots[(int)handle.mIndex] = slot;
		mFreeList.Add(handle.mIndex);
		mLiveCount--;
		return true;
	}
}
