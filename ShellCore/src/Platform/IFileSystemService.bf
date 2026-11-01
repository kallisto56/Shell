namespace Shell.Platform;

using System;
using System.Collections;

// All file access of the shell goes through this interface. The Windows implementation talks to the real file system;
// the simulation implements it over a virtual file system that can never touch the host.
interface IFileSystemService
{
	IFileListOperation List(StringView path);
	IOperation CreateFolder(StringView path);
	IOperation Rename(StringView path, StringView newName);
	IOperation Move(List<String> sources, StringView destinationFolder);
	IOperation Copy(List<String> sources, StringView destinationFolder);
	IOperation Delete(List<String> paths, DeleteMode mode);
	bool Exists(StringView path);
}
