namespace Shell.Simulation;

using System;
using Shell.Platform;

// Stand-in for the IME / text services framework in the editor simulation. The focused text widget attaches itself as the
// client; tests and the editor's "simulate IME" tool drive composition through the Simulate* methods, exactly in the order a real
// IME would (composition updates, then a commit with the final text, or a cancel).
class SimulatedTextInputService : ITextInputService
{
	public ITextInputClient mClient;
	public int mCaretNotifications;

	public void Attach(ITextInputClient client)
	{
		mClient = client;
	}

	public void Detach(ITextInputClient client)
	{
		if (mClient == client)
			mClient = null;
	}

	public void NotifyCaretMoved()
	{
		mCaretNotifications++;
	}

	public bool SimulateComposition(StringView text, int cursor)
	{
		if (mClient == null)
			return false;
		mClient.SetComposition(text, cursor);
		return true;
	}

	public bool SimulateCommit(StringView text)
	{
		if (mClient == null)
			return false;
		mClient.GetSelection(var start, var end);
		mClient.SetComposition("", 0);
		mClient.ReplaceText(start, end, text);
		return true;
	}

	public bool SimulateCancel()
	{
		if (mClient == null)
			return false;
		mClient.SetComposition("", 0);
		return true;
	}
}
