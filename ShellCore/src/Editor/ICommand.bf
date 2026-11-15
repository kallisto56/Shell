namespace Shell.Editor;

using System;

// Every edit in the editor is a command: it changes the model, can be undone, and may merge with the next command
// (typing, dragging a slider). The model is changed only through commands, so undo/redo is complete by construction.
interface ICommand
{
	StringView GetName();
	void Do();
	void Undo();
	// Return true if `next` was folded into this command (same target and gesture).
	bool TryMerge(ICommand next);
}
