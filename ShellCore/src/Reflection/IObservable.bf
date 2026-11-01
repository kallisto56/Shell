namespace Shell.Reflection;

using System;

interface IObservable
{
	uint64 GetVersion();
	void AddObserver(IInvalidationObserver observer);
	void RemoveObserver(IInvalidationObserver observer);
}
