namespace Shell.PlatformWin;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

// The real file system. All calls complete synchronously on the calling (update) thread and return an already finished
// operation; long copies will move to a worker thread when the shell gets a progress UI (the IOperation contract already allows it).
// Copy/move never overwrite silently: name collisions are renamed ("name (2)") by the shell operation.
// Delete(Recycle) uses the Recycle Bin, Delete(Permanent) removes for good. Prompts and error dialogs are suppressed:
// the shell UI shows its own.
class WinFileSystemService : IFileSystemService
{
	OperationLog mLog;

	public this(OperationLog log)
	{
		mLog = log;
	}

	static void Wide(StringView path, List<char16> output)
	{
		let converted = scope String(path);
		converted.Replace('/', '\\');
		WideString.Encode(converted, output);
	}

	public IFileListOperation List(StringView path)
	{
		let operation = mLog.Add(new ImmediateFileListOperation());
		let found = scope List<FoundEntry>();
		let error = WinFind.Enumerate(path, found);
		if (error != 0)
		{
			operation.Fail(WinErrors.FromLastError(error, scope $"Listing '{path}'"));
			DeleteContainerAndItems!(found);
			return operation;
		}

		found.Sort(scope (a, b) =>
		{
			if (a.mIsDirectory != b.mIsDirectory)
				return a.mIsDirectory ? -1 : 1;
			return String.Compare(a.mName, b.mName, true);
		});

		for (let item in found)
		{
			let entry = new FileEntry();
			entry.mName.Set(item.mName);
			entry.mPath.Set(path);
			entry.mPath.Replace('\\', '/');
			if (!entry.mPath.EndsWith('/'))
				entry.mPath.Append('/');
			entry.mPath.Append(item.mName);
			entry.mKind = ((item.mAttributes & 0x400) != 0) ? FileKind.Link : (item.mIsDirectory ? FileKind.Directory : FileKind.File);
			entry.mSize = item.mSize;
			entry.mModifiedUtcTicks = item.mModifiedUtcTicks;
			entry.bHidden = (item.mAttributes & 2) != 0;
			entry.bReadOnly = (item.mAttributes & 1) != 0;
			operation.mEntries.Add(entry);
		}
		DeleteContainerAndItems!(found);
		return operation;
	}

	public IOperation CreateFolder(StringView path)
	{
		let operation = mLog.Add(new ImmediateOperation());
		let wide = scope List<char16>();
		Wide(path, wide);
		if (NativeKernel32.CreateDirectoryW(wide.Ptr, null) == 0)
			operation.Fail(WinErrors.FromLastError(NativeKernel32.GetLastError(), scope $"Creating '{path}'"));
		return operation;
	}

	public IOperation Rename(StringView path, StringView newName)
	{
		let operation = mLog.Add(new ImmediateOperation());
		if (newName.IsEmpty || newName.Contains('/') || newName.Contains('\\'))
		{
			operation.Fail(WinErrors.Make("invalid-name", scope $"'{newName}' is not a valid file name."));
			return operation;
		}

		let normalized = scope String(path);
		normalized.Replace('\\', '/');
		let slash = normalized.LastIndexOf('/');
		let target = scope String();
		if (slash >= 0)
			target.Append(normalized, 0, slash + 1);
		target.Append(newName);

		let from = scope List<char16>();
		let to = scope List<char16>();
		Wide(normalized, from);
		Wide(target, to);
		if (NativeKernel32.MoveFileExW(from.Ptr, to.Ptr, 0) == 0)
			operation.Fail(WinErrors.FromLastError(NativeKernel32.GetLastError(), scope $"Renaming '{path}'"));
		return operation;
	}

	IOperation RunShellOperation(uint32 @function, List<String> sources, StringView destination, uint16 flags, StringView what)
	{
		let operation = mLog.Add(new ImmediateOperation());
		if (sources.Count == 0)
			return operation;

		let from = scope List<char16>();
		WideString.EncodeList(sources, from);
		let to = scope List<char16>();
		if (!destination.IsEmpty)
		{
			let list = scope List<String>();
			let owned = scope String(destination);
			list.Add(owned);
			WideString.EncodeList(list, to);
		}

		SHFILEOPSTRUCTW op = default;
		op.wFunc = @function;
		op.pFrom = from.Ptr;
		op.pTo = destination.IsEmpty ? null : to.Ptr;
		op.fFlags = flags;
		let result = NativeShell32.SHFileOperationW(&op);
		if (op.fAnyOperationsAborted != 0)
			operation.mStatus = .Cancelled;
		else if (result != 0)
			operation.Fail(WinErrors.Make(scope $"shell-error-{result}", scope $"{what} failed (shell error 0x{result:X})."));
		return operation;
	}

	// FOF_SILENT 0x4 | FOF_RENAMEONCOLLISION 0x8 | FOF_NOCONFIRMATION 0x10 | FOF_NOCONFIRMMKDIR 0x200 | FOF_NOERRORUI 0x400
	const uint16 cQuiet = 0x4 | 0x10 | 0x200 | 0x400;

	public IOperation Move(List<String> sources, StringView destinationFolder)
	{
		return RunShellOperation(1, sources, destinationFolder, cQuiet | 0x8, "Moving");
	}

	public IOperation Copy(List<String> sources, StringView destinationFolder)
	{
		return RunShellOperation(2, sources, destinationFolder, cQuiet | 0x8, "Copying");
	}

	public IOperation Delete(List<String> paths, DeleteMode mode)
	{
		let flags = (mode == .Recycle) ? (cQuiet | 0x40) : cQuiet;     // FOF_ALLOWUNDO = recycle bin
		return RunShellOperation(3, paths, "", flags, "Deleting");
	}

	public bool Exists(StringView path)
	{
		let wide = scope List<char16>();
		Wide(path, wide);
		return NativeKernel32.GetFileAttributesW(wide.Ptr) != 0xFFFFFFFF;
	}
}
