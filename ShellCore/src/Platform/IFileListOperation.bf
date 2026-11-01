namespace Shell.Platform;

using System;
using System.Collections;

interface IFileListOperation : IOperation
{
	// Valid when Succeeded. Entries are in a stable, documented order: directories first, then files, each by name.
	List<FileEntry> GetEntries();
}
