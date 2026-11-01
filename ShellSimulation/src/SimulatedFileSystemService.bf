namespace Shell.Simulation;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

class SimulatedFileSystemService : IFileSystemService
{
	public VirtualFileSystem mFileSystem;       // not owned
	OperationScheduler mScheduler;

	public this(VirtualFileSystem fileSystem, OperationScheduler scheduler)
	{
		mFileSystem = fileSystem;
		mScheduler = scheduler;
	}

	public IFileListOperation List(StringView path)
	{
		return mScheduler.Start(new ListFilesOperation(mFileSystem, path), "files.list", path);
	}

	public IOperation CreateFolder(StringView path)
	{
		let op = new FileMutationOperation(mFileSystem, .CreateFolder);
		op.SetTarget(path);
		return mScheduler.Start(op, "files.createfolder", path);
	}

	public IOperation Rename(StringView path, StringView newName)
	{
		let op = new FileMutationOperation(mFileSystem, .Rename);
		op.AddSource(path);
		op.SetTarget(newName);
		return mScheduler.Start(op, "files.rename", path);
	}

	public IOperation Move(List<String> sources, StringView destinationFolder)
	{
		let op = new FileMutationOperation(mFileSystem, .Move);
		for (let source in sources)
			op.AddSource(source);
		op.SetTarget(destinationFolder);
		return mScheduler.Start(op, "files.move", (sources.Count > 0) ? StringView(sources[0]) : StringView());
	}

	public IOperation Copy(List<String> sources, StringView destinationFolder)
	{
		let op = new FileMutationOperation(mFileSystem, .Copy);
		for (let source in sources)
			op.AddSource(source);
		op.SetTarget(destinationFolder);
		return mScheduler.Start(op, "files.copy", (sources.Count > 0) ? StringView(sources[0]) : StringView());
	}

	public IOperation Delete(List<String> paths, DeleteMode mode)
	{
		let op = new FileMutationOperation(mFileSystem, .Delete);
		for (let path in paths)
			op.AddSource(path);
		op.SetDeleteMode(mode);
		return mScheduler.Start(op, "files.delete", (paths.Count > 0) ? StringView(paths[0]) : StringView());
	}

	public bool Exists(StringView path)
	{
		return mFileSystem.Find(path) != null;
	}
}
