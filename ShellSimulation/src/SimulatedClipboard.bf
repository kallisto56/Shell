namespace Shell.Simulation;

using System;
using Shell.Platform;

class SimulatedClipboard : IClipboardService
{
	String mText = new .() ~ delete _;

	public bool GetText(String output)
	{
		if (mText.IsEmpty)
			return false;
		output.Append(mText);
		return true;
	}

	public void SetText(StringView text)
	{
		mText.Set(text);
	}
}
