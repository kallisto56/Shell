namespace Shell.Simulation;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

class ListFilesOperation : SimulatedOperation, IFileListOperation
{
	VirtualFileSystem mFileSystem;
	String mPath = new .() ~ delete _;
	List<FileEntry> mEntries = new .() ~ DeleteContainerAndItems!(_);

	public this(VirtualFileSystem fileSystem, StringView path)
	{
		mFileSystem = fileSystem;
		mPath.Set(path);
	}

	public List<FileEntry> GetEntries() => mEntries;

	public override OperationError Execute()
	{
		let folder = mFileSystem.Find(mPath);
		if (folder == null)
			return MakeError("not-found", scope $"The path '{mPath}' does not exist.");
		if (!folder.mIsFolder)
			return MakeError("not-a-folder", scope $"'{mPath}' is not a folder.");

		let nodes = scope List<VirtualFileNode>();
		nodes.AddRange(folder.mChildren);
		VirtualFileSystem.SortForListing(nodes);
		for (let node in nodes)
		{
			let entry = new FileEntry();
			entry.mName.Set(node.mName);
			node.GetPath(entry.mPath);
			entry.mKind = node.mKind;
			entry.mSize = node.mSize;
			entry.mModifiedUtcTicks = node.mModifiedUtcTicks;
			entry.bHidden = node.bHidden;
			entry.bReadOnly = node.bReadOnly;
			mEntries.Add(entry);
		}
		return null;
	}
}
