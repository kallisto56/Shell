namespace Shell.Simulation;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

// Create / rename / move / copy / delete on the virtual file system. Several sources are processed in order; the first
// failure stops the operation and earlier items stay applied (like a real multi-file operation).
class FileMutationOperation : SimulatedOperation
{
	VirtualFileSystem mFileSystem;
	FileOperationKind mKind;
	List<String> mSources = new .() ~ DeleteContainerAndItems!(_);
	String mTarget = new .() ~ delete _;        // destination folder, new name or new folder path
	DeleteMode mDeleteMode;

	public this(VirtualFileSystem fileSystem, FileOperationKind kind)
	{
		mFileSystem = fileSystem;
		mKind = kind;
	}

	public void AddSource(StringView path)
	{
		mSources.Add(new String(path));
	}

	public void SetTarget(StringView target) { mTarget.Set(target); }
	public void SetDeleteMode(DeleteMode mode) { mDeleteMode = mode; }

	static OperationError Translate(VfsError error, StringView path)
	{
		switch (error)
		{
		case .None: return null;
		case .NotFound: return MakeError("not-found", scope $"'{path}' does not exist.");
		case .AlreadyExists: return MakeError("already-exists", scope $"'{path}' already exists.");
		case .AccessDenied: return MakeError("access-denied", scope $"Access to '{path}' was denied.");
		case .InvalidName: return MakeError("invalid-name", scope $"The name in '{path}' is not valid.");
		case .InvalidDestination: return MakeError("invalid-destination", scope $"'{path}' cannot be used as the destination.");
		}
	}

	public override OperationError Execute()
	{
		if (mKind == .CreateFolder)
			return Translate(mFileSystem.CreateFolder(mTarget), mTarget);

		for (let source in mSources)
		{
			let node = mFileSystem.Find(source);
			if (node == null)
				return Translate(.NotFound, source);

			VfsError result = .None;
			switch (mKind)
			{
			case .Rename:
				result = mFileSystem.Rename(node, mTarget);
			case .Move, .Copy:
			{
				let destination = mFileSystem.Find(mTarget);
				if (destination == null)
					return Translate(.NotFound, mTarget);
				let name = scope String(node.mName);
				result = (mKind == .Move) ? mFileSystem.Move(node, destination, name) : mFileSystem.Copy(node, destination, name);
			}
			case .Delete:
				result = (mDeleteMode == .Recycle) ? mFileSystem.MoveToRecycleBin(node) : mFileSystem.Remove(node);
			default:
			}

			if (result != .None)
				return Translate(result, source);
		}
		return null;
	}
}
