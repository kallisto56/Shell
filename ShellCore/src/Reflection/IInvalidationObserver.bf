namespace Shell.Reflection;

using System;

// Notified synchronously when an observed source changed. Implementations must only mark themselves dirty;
// re-evaluation happens in the Bindings phase (no re-entrant evaluation, no cascades inside the notification).
interface IInvalidationObserver
{
	void OnSourceChanged(IObservable source);
}
