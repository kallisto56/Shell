namespace Shell.Reflection;

using System;
using System.Collections;

// Version counter + observer list. Used for property slots, global variables, style tokens and time values.
class ObservableValue : IObservable
{
	uint64 mVersion = 1;
	List<IInvalidationObserver> mObservers = new .() ~ delete _;
	int mNotifyDepth;

	public uint64 GetVersion()
	{
		return mVersion;
	}

	public void AddObserver(IInvalidationObserver observer)
	{
		if (!mObservers.Contains(observer))
			mObservers.Add(observer);
	}

	public void RemoveObserver(IInvalidationObserver observer)
	{
		// Observers may unsubscribe from inside a notification: null the slot, compact afterwards.
		let index = mObservers.IndexOf(observer);
		if (index < 0)
			return;
		if (mNotifyDepth > 0)
			mObservers[index] = null;
		else
			mObservers.RemoveAt(index);
	}

	public void NotifyChanged()
	{
		mVersion++;
		mNotifyDepth++;
		for (int i = 0; i < mObservers.Count; i++)
		{
			let observer = mObservers[i];
			if (observer != null)
				observer.OnSourceChanged(this);
		}
		mNotifyDepth--;
		if (mNotifyDepth == 0)
			mObservers.RemoveAll(scope (o) => o == null);
	}
}
