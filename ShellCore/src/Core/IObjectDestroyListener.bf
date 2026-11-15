namespace Shell.Core;

using System;

// Notified right before a RuntimeObject is destroyed (Commit phase), while the object is still fully valid. Systems that keep
// non-owning references (focus, pointer capture, hover, binding lists, text input) use it to drop them.
interface IObjectDestroyListener
{
	void OnObjectDestroying(RuntimeObject object);
}
