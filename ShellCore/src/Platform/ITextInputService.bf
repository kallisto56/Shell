namespace Shell.Platform;

using System;

interface ITextInputService
{
	// The focused widget attaches itself while it has keyboard focus and detaches when it loses it.
	void Attach(ITextInputClient client);
	void Detach(ITextInputClient client);
	void NotifyCaretMoved();
}
