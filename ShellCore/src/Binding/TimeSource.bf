namespace Shell.Binding;

using System;
using Shell.Core;
using Shell.Reflection;

// Built-in time values as observable sources. Updated once per frame (Timers phase) from the FrameContext, so every
// Blueprint, animation and binding sees the same time within a frame.
class TimeSource
{
	ObservableValue[4] mObservables;
	double[4] mValues;

	public this()
	{
		for (int i < 4)
			mObservables[i] = new ObservableValue();
	}

	public ~this()
	{
		for (int i < 4)
			delete mObservables[i];
	}

	public void Update(FrameContext frame)
	{
		Set(.Time, frame.mTime);
		Set(.UnscaledTime, frame.mUnscaledTime);
		Set(.DeltaTime, (double)frame.mDeltaTime);
		Set(.UnscaledDeltaTime, (double)frame.mUnscaledDeltaTime);
	}

	void Set(TimeBuiltin kind, double value)
	{
		mValues[(int)kind] = value;
		mObservables[(int)kind].NotifyChanged();
	}

	public double Get(TimeBuiltin kind) => mValues[(int)kind];
	public IObservable Observe(TimeBuiltin kind) => mObservables[(int)kind];
}
