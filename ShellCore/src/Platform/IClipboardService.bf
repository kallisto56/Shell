namespace Shell.Platform;

using System;

interface IClipboardService
{
	bool GetText(String output);
	void SetText(StringView text);
}
