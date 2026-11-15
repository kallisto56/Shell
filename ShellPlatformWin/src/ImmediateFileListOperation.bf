namespace Shell.PlatformWin;

using System;
using System.Collections;
using Shell.Platform;

class ImmediateFileListOperation : ImmediateOperation, IFileListOperation
{
	public List<FileEntry> mEntries = new .() ~ DeleteContainerAndItems!(_);
	public List<FileEntry> GetEntries() => mEntries;
}
