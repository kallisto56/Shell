namespace Shell.Platform;

using System;

interface IShellIntegration
{
	String GetSpecialFolderPath(SpecialFolder folder);      // caller owns the returned string; null if unavailable
	IOperation OpenPath(StringView path);                   // default handler (Explorer / associated application)
	IOperation ShowProperties(StringView path);
	IOperation EmptyRecycleBin();
	IOperation Shutdown(bool restart);
	IOperation Lock();
	IOperation SignOut();
}
