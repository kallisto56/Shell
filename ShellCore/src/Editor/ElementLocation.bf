namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;

struct ElementLocation
{
	public ElementNodeData mElement;
	public ElementNodeData mParent;         // null for the skin root
	public int mIndex;
}

static class ElementQueries
{
	static public Result<ElementLocation> Locate(ElementTreeData tree, StableId id)
	{
		if (tree.mRoot == null)
			return .Err;
		if (tree.mRoot.mId == id)
			return .Ok(ElementLocation() { mElement = tree.mRoot, mParent = null, mIndex = 0 });
		return LocateIn(tree.mRoot, id);
	}

	static Result<ElementLocation> LocateIn(ElementNodeData parent, StableId id)
	{
		for (int i < parent.mChildren.Count)
		{
			let child = parent.mChildren[i];
			if (child.mId == id)
				return .Ok(ElementLocation() { mElement = child, mParent = parent, mIndex = i });
			let nested = LocateIn(child, id);
			if (nested case .Ok)
				return nested;
		}
		return .Err;
	}

	static public bool IsInside(ElementNodeData ancestor, ElementNodeData node)
	{
		if (ancestor == node)
			return true;
		for (let child in ancestor.mChildren)
		{
			if (IsInside(child, node))
				return true;
		}
		return false;
	}

	static public bool ContainsEssential(ElementNodeData node)
	{
		if (node.bEssential)
			return true;
		for (let child in node.mChildren)
		{
			if (ContainsEssential(child))
				return true;
		}
		return false;
	}
}
