namespace Shell.Simulation;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

class VirtualFileNode
{
	public String mName = new .() ~ delete _;
	public FileKind mKind;
	public uint64 mSize;
	public int64 mModifiedUtcTicks;
	public bool bHidden;
	public bool bReadOnly;
	public VirtualFileNode mParent;
	public List<VirtualFileNode> mChildren = new .() ~ DeleteContainerAndItems!(_);

	public bool mIsFolder => mKind == .Directory || mKind == .Drive;

	public VirtualFileNode FindChild(StringView name)
	{
		for (let child in mChildren)
		{
			if (child.mName.Equals(name, true))
				return child;
		}
		return null;
	}

	// "C:/Users/Me" style path; the virtual root has the empty path.
	public void GetPath(String output)
	{
		if (mParent == null)
			return;
		if (mParent.mParent != null)
		{
			mParent.GetPath(output);
			output.Append('/');
		}
		output.Append(mName);
	}

	public bool IsInside(VirtualFileNode ancestor)
	{
		for (var node = this; node != null; node = node.mParent)
		{
			if (node == ancestor)
				return true;
		}
		return false;
	}

	public VirtualFileNode Clone()
	{
		let copy = new VirtualFileNode();
		copy.mName.Set(mName);
		copy.mKind = mKind;
		copy.mSize = mSize;
		copy.mModifiedUtcTicks = mModifiedUtcTicks;
		copy.bHidden = bHidden;
		copy.bReadOnly = bReadOnly;
		for (let child in mChildren)
		{
			let childCopy = child.Clone();
			childCopy.mParent = copy;
			copy.mChildren.Add(childCopy);
		}
		return copy;
	}
}
