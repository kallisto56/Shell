namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

// Changes the owner of an element inside its skin (identity, bindings and properties stay).
class MoveElementCommand : DefinitionCommand
{
	ElementNodeData mElement;
	ElementNodeData mOldParent;
	int mOldIndex;
	ElementNodeData mNewParent;
	int mNewIndex;

	public this(DefinitionEditSession session, ElementNodeData element, ElementNodeData oldParent, int oldIndex, ElementNodeData newParent, int newIndex) : base(session, "Move element")
	{
		mElement = element;
		mOldParent = oldParent;
		mOldIndex = oldIndex;
		mNewParent = newParent;
		mNewIndex = newIndex;
	}

	protected override void Apply()
	{
		mOldParent.mChildren.Remove(mElement);
		mNewParent.mChildren.Insert(Math.Clamp(mNewIndex, 0, mNewParent.mChildren.Count), mElement);
	}

	protected override void Revert()
	{
		mNewParent.mChildren.Remove(mElement);
		mOldParent.mChildren.Insert(Math.Clamp(mOldIndex, 0, mOldParent.mChildren.Count), mElement);
	}
}
