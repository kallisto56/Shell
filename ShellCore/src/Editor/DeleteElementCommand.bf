namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

class DeleteElementCommand : DefinitionCommand
{
	ElementNodeData mElement;
	ElementNodeData mParent;
	int mIndex;
	bool bDeleted;

	public this(DefinitionEditSession session, ElementNodeData element, ElementNodeData parent, int index) : base(session, "Delete element")
	{
		mElement = element;
		mParent = parent;
		mIndex = index;
	}

	public ~this()
	{
		if (bDeleted)
			delete mElement;
	}

	protected override void Apply()
	{
		mParent.mChildren.Remove(mElement);
		bDeleted = true;
	}

	protected override void Revert()
	{
		mParent.mChildren.Insert(Math.Clamp(mIndex, 0, mParent.mChildren.Count), mElement);
		bDeleted = false;
	}
}
