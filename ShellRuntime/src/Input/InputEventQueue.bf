namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Input;

// Platform -> widget runtime hand-over. The window procedure (or the editor's host window, or a test) enqueues events at any
// time during message processing; the InputRouter drains them in the Input phase, so widgets only ever see input at a
// defined point of the frame and in the order it happened.
class InputEventQueue
{
	List<InputEntry> mEntries = new .() ~ DeleteContainerAndItems!(_);

	public int mCount => mEntries.Count;

	public void EnqueuePointer(PointerEvent e)
	{
		let entry = new InputEntry();
		entry.mKind = .Pointer;
		entry.mPointer = e;
		mEntries.Add(entry);
	}

	public void EnqueueKey(KeyEvent e)
	{
		let entry = new InputEntry();
		entry.mKind = .Key;
		entry.mKey = e;
		mEntries.Add(entry);
	}

	public void EnqueueText(StringView text)
	{
		let entry = new InputEntry();
		entry.mKind = .Text;
		entry.mText.Set(text);
		mEntries.Add(entry);
	}

	public void EnqueueCancel()
	{
		let entry = new InputEntry();
		entry.mKind = .Cancel;
		mEntries.Add(entry);
	}

	// Moves all queued entries to `output` (caller deletes them).
	public void Drain(List<InputEntry> output)
	{
		output.AddRange(mEntries);
		mEntries.Clear();
	}
}
