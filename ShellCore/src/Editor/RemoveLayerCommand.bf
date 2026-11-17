namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

// Removes a layer; elements assigned to it fall back to the Content layer (their ownership is untouched).
class RemoveLayerCommand : DefinitionCommand
{
	ElementTreeData mTree;
	LayerDefinition mLayer;
	int mIndex;
	StableId mContent;
	List<ElementNodeData> mMoved = new .() ~ delete _;
	bool bRemoved;

	public this(DefinitionEditSession session, ElementTreeData tree, LayerDefinition layer, StableId content) : base(session, "Remove layer")
	{
		mTree = tree;
		mLayer = layer;
		mContent = content;
	}

	public ~this()
	{
		if (bRemoved)
			delete mLayer;
	}

	void Collect(ElementNodeData node)
	{
		if (node.mLayer == mLayer.mId)
			mMoved.Add(node);
		for (let child in node.mChildren)
			Collect(child);
	}

	protected override void Apply()
	{
		mMoved.Clear();
		if (mTree.mRoot != null)
			Collect(mTree.mRoot);
		for (let element in mMoved)
			element.mLayer = mContent;
		mIndex = mTree.mLayers.IndexOf(mLayer);
		mTree.mLayers.Remove(mLayer);
		bRemoved = true;
	}

	protected override void Revert()
	{
		mTree.mLayers.Insert(Math.Min(mIndex, mTree.mLayers.Count), mLayer);
		for (let element in mMoved)
			element.mLayer = mLayer.mId;
		bRemoved = false;
	}
}
