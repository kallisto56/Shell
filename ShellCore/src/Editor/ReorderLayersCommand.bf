namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

// Gives layers new order values (the editor renumbers the whole sequence so the Content layer stays at order 0, which is where the
// widget's child widgets are drawn).
class ReorderLayersCommand : DefinitionCommand
{
	ElementTreeData mTree;
	List<(StableId id, int oldOrder, int newOrder)> mChanges = new .() ~ delete _;

	public this(DefinitionEditSession session, ElementTreeData tree) : base(session, "Reorder layers")
	{
		mTree = tree;
	}

	public void Add(StableId id, int oldOrder, int newOrder)
	{
		mChanges.Add((id, oldOrder, newOrder));
	}

	public bool mHasChanges => mChanges.Count > 0;

	void Set(bool bNew)
	{
		for (let change in mChanges)
		{
			for (let layer in mTree.mLayers)
			{
				if (layer.mId == change.id)
					layer.mOrder = bNew ? change.newOrder : change.oldOrder;
			}
		}
		mTree.mLayers.Sort(scope (a, b) => a.mOrder <=> b.mOrder);
	}

	protected override void Apply() => Set(true);
	protected override void Revert() => Set(false);
}
