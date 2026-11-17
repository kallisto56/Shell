namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

// Adds a new element to a skin. Also the Undo of a delete.
class InsertElementCommand : DefinitionCommand
{
	ElementNodeData mElement;
	ElementNodeData mParent;
	int mIndex;
	bool bInserted;

	public this(DefinitionEditSession session, ElementNodeData element, ElementNodeData parent, int index) : base(session, "Add element")
	{
		mElement = element;
		mParent = parent;
		mIndex = index;
	}

	public ~this()
	{
		if (!bInserted)
			delete mElement;
	}

	protected override void Apply()
	{
		mParent.mChildren.Insert(Math.Clamp(mIndex, 0, mParent.mChildren.Count), mElement);
		bInserted = true;
	}

	protected override void Revert()
	{
		mParent.mChildren.Remove(mElement);
		bInserted = false;
	}
}
