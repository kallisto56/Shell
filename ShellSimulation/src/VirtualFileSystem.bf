namespace Shell.Simulation;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

// In-memory file system. Pure data and rules, no timing: the simulated service wraps it in operations. It never touches
// the host's disks. Paths use '/' (a '\' is accepted and converted), drives look like "C:", comparison ignores case.
class VirtualFileSystem
{
	public VirtualFileNode mRoot = new .() ~ delete _;
	public VirtualFileNode mRecycleBin;
	public int64 mNowUtcTicks;                  // stamped on modified entries; the environment keeps it in sync with its clock

	public this()
	{
		mRecycleBin = new VirtualFileNode();
		mRecycleBin.mName.Set("$Recycle.Bin");
		mRecycleBin.mKind = .Directory;
		mRecycleBin.bHidden = true;
		mRecycleBin.mParent = mRoot;
		mRoot.mChildren.Add(mRecycleBin);
	}

	static void Split(StringView path, List<StringView> parts)
	{
		for (let part in path.Split('/', .RemoveEmptyEntries))
		{
			let trimmed = part.Trim();
			if (!trimmed.IsEmpty)
				parts.Add(trimmed);
		}
	}

	public VirtualFileNode Find(StringView path)
	{
		let normalized = scope String(path);
		normalized.Replace('\\', '/');
		let parts = scope List<StringView>();
		Split(normalized, parts);

		var node = mRoot;
		for (let part in parts)
		{
			node = node.FindChild(part);
			if (node == null)
				return null;
		}
		return node;
	}

	static public bool IsValidName(StringView name)
	{
		if (name.IsEmpty || name == "." || name == "..")
			return false;
		for (let c in name)
		{
			if (c == '/' || c == '\\' || c == ':' || c == '*' || c == '?' || c == '"' || c == '<' || c == '>' || c == '|' || c < ' ')
				return false;
		}
		return true;
	}

	VirtualFileNode AddNode(VirtualFileNode parent, StringView name, FileKind kind)
	{
		let node = new VirtualFileNode();
		node.mName.Set(name);
		node.mKind = kind;
		node.mModifiedUtcTicks = mNowUtcTicks;
		node.mParent = parent;
		parent.mChildren.Add(node);
		return node;
	}

	// ---- Scenario building (creates missing folders, replaces nothing) ----

	public VirtualFileNode EnsureFolder(StringView path)
	{
		let normalized = scope String(path);
		normalized.Replace('\\', '/');
		let parts = scope List<StringView>();
		Split(normalized, parts);

		var node = mRoot;
		for (let part in parts)
		{
			var next = node.FindChild(part);
			if (next == null)
				next = AddNode(node, part, (node == mRoot) ? FileKind.Drive : FileKind.Directory);
			node = next;
		}
		return node;
	}

	public VirtualFileNode AddFile(StringView path, uint64 size, bool hidden = false, bool readOnly = false)
	{
		let normalized = scope String(path);
		normalized.Replace('\\', '/');
		let slash = normalized.LastIndexOf('/');
		let folder = (slash > 0) ? EnsureFolder(normalized.Substring(0, slash)) : mRoot;
		let name = normalized.Substring(slash + 1);

		var node = folder.FindChild(name);
		if (node == null)
			node = AddNode(folder, name, .File);
		node.mSize = size;
		node.bHidden = hidden;
		node.bReadOnly = readOnly;
		return node;
	}

	// ---- Operations (return VfsError.None on success) ----

	public VfsError CreateFolder(StringView path)
	{
		let normalized = scope String(path);
		normalized.Replace('\\', '/');
		let slash = normalized.LastIndexOf('/');
		if (slash <= 0)
			return .InvalidName;

		let parent = Find(normalized.Substring(0, slash));
		let name = normalized.Substring(slash + 1);
		if (parent == null)
			return .NotFound;
		if (!parent.mIsFolder)
			return .InvalidDestination;
		if (!IsValidName(name))
			return .InvalidName;
		if (parent.FindChild(name) != null)
			return .AlreadyExists;

		AddNode(parent, name, .Directory);
		parent.mModifiedUtcTicks = mNowUtcTicks;
		return .None;
	}

	public VfsError Rename(VirtualFileNode node, StringView newName)
	{
		if (!IsValidName(newName))
			return .InvalidName;
		if (node.bReadOnly)
			return .AccessDenied;
		let existing = node.mParent.FindChild(newName);
		if (existing != null && existing != node)
			return .AlreadyExists;
		node.mName.Set(newName);
		node.mModifiedUtcTicks = mNowUtcTicks;
		return .None;
	}

	static void Detach(VirtualFileNode node)
	{
		node.mParent.mChildren.Remove(node);
		node.mParent = null;
	}

	public VfsError Move(VirtualFileNode node, VirtualFileNode destination, StringView newName)
	{
		if (!destination.mIsFolder || destination.IsInside(node))
			return .InvalidDestination;
		if (node.bReadOnly)
			return .AccessDenied;
		if (destination.FindChild(newName) != null)
			return .AlreadyExists;

		Detach(node);
		node.mName.Set(newName);
		node.mParent = destination;
		destination.mChildren.Add(node);
		node.mModifiedUtcTicks = mNowUtcTicks;
		return .None;
	}

	public VfsError Copy(VirtualFileNode node, VirtualFileNode destination, StringView newName)
	{
		if (!destination.mIsFolder || destination.IsInside(node))
			return .InvalidDestination;
		if (destination.FindChild(newName) != null)
			return .AlreadyExists;

		let copy = node.Clone();
		copy.mName.Set(newName);
		copy.bReadOnly = false;
		copy.mModifiedUtcTicks = mNowUtcTicks;
		copy.mParent = destination;
		destination.mChildren.Add(copy);
		return .None;
	}

	public VfsError Remove(VirtualFileNode node)
	{
		if (node.bReadOnly)
			return .AccessDenied;
		if (node.mParent == null || node == mRecycleBin)
			return .InvalidDestination;
		Detach(node);
		delete node;
		return .None;
	}

	public VfsError MoveToRecycleBin(VirtualFileNode node)
	{
		if (node.mParent == null || node == mRecycleBin || node.IsInside(mRecycleBin))
			return .InvalidDestination;

		// Keep names unique inside the bin (like "name (2)").
		let name = scope String(node.mName);
		var counter = 2;
		while (mRecycleBin.FindChild(name) != null)
		{
			name.Clear();
			name.AppendF("{} ({})", node.mName, counter++);
		}
		Detach(node);
		node.mName.Set(name);
		node.mParent = mRecycleBin;
		mRecycleBin.mChildren.Add(node);
		return .None;
	}

	public void EmptyRecycleBin()
	{
		DeleteAndClearItems!(mRecycleBin.mChildren);
	}

	// Directories first, then files; each group sorted by name (ordinal, ignoring case).
	static public void SortForListing(List<VirtualFileNode> nodes)
	{
		nodes.Sort(scope (a, b) =>
		{
			if (a.mIsFolder != b.mIsFolder)
				return a.mIsFolder ? -1 : 1;
			return String.Compare(a.mName, b.mName, true);
		});
	}

	// Replaces this file system's content with a deep copy of `other` (same object identity, so services keep working).
	public void CopyFrom(VirtualFileSystem other)
	{
		DeleteAndClearItems!(mRoot.mChildren);
		mRecycleBin = null;
		for (let child in other.mRoot.mChildren)
		{
			let childCopy = child.Clone();
			childCopy.mParent = mRoot;
			mRoot.mChildren.Add(childCopy);
			if (child == other.mRecycleBin)
				mRecycleBin = childCopy;
		}
		mNowUtcTicks = other.mNowUtcTicks;
	}

	public VirtualFileSystem Clone()
	{
		let copy = new VirtualFileSystem();
		copy.CopyFrom(this);
		return copy;
	}
}
