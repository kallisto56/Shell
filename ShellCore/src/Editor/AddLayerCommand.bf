namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

class AddLayerCommand : DefinitionCommand
{
	ElementTreeData mTree;
	LayerDefinition mLayer;
	bool bAdded;

	public this(DefinitionEditSession session, ElementTreeData tree, LayerDefinition layer) : base(session, "Add layer")
	{
		mTree = tree;
		mLayer = layer;
	}

	public ~this()
	{
		if (!bAdded)
			delete mLayer;
	}

	protected override void Apply()
	{
		mTree.mLayers.Add(mLayer);
		bAdded = true;
	}

	protected override void Revert()
	{
		mTree.mLayers.Remove(mLayer);
		bAdded = false;
	}
}
