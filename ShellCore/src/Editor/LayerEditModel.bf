namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

// View-model of the layer editor: the layers of a widget skin from back to front, each with the elements drawn in it. Mirrors what
// RenderListBuilder produces at run time, but is computed from the saved description, so it works while nothing is running.
//
// The ownership tree is not changed by anything shown here: moving an element between layers only changes where it is drawn.
// The point between the rows with bBeforeChildren and the others is where child widgets are drawn.
static class LayerEditModel
{
	// The caller deletes the rows.
	static public void Build(ElementTreeData tree, List<LayerRow> output)
	{
		let layers = scope List<LayerDefinition>();
		layers.AddRange(tree.mLayers);
		layers.Sort(scope (a, b) => a.mOrder <=> b.mOrder);

		StableId content = .sNone;
		for (let layer in layers)
		{
			if (layer.mRole == .Content)
				content = layer.mId;
		}

		for (let layer in layers)
		{
			let row = new LayerRow();
			row.mId = layer.mId;
			row.mName.Set(layer.mName);
			row.mRole = layer.mRole;
			row.mOrder = layer.mOrder;
			row.bEssential = layer.bEssential;
			row.bBeforeChildren = layer.mOrder <= 0;
			if (tree.mRoot != null)
				Emit(tree, tree.mRoot, layer.mId, content, 0, row);
			output.Add(row);
		}
	}

	static bool LayerExists(ElementTreeData tree, StableId id)
	{
		for (let layer in tree.mLayers)
		{
			if (layer.mId == id)
				return true;
		}
		return false;
	}

	static void Emit(ElementTreeData tree, ElementNodeData element, StableId layer, StableId inherited, int depth, LayerRow row)
	{
		let own = element.mLayer.mIsValid && LayerExists(tree, element.mLayer);
		let effective = own ? element.mLayer : inherited;
		if (effective == layer)
		{
			let entry = new LayerEntry();
			entry.mElement = element.mId;
			entry.mName.Set(element.mName.IsEmpty ? element.mTypeName : StringView(element.mName));
			if (entry.mName.IsEmpty)
				entry.mName.AppendF("{}", element.mKind);
			entry.mDepth = depth;
			entry.bInherited = !own;
			entry.bEssential = element.bEssential;
			row.mEntries.Add(entry);
		}

		let ordered = scope List<(int z, int index)>();
		for (int i < element.mChildren.Count)
			ordered.Add((element.mChildren[i].mZIndex, i));
		ordered.Sort(scope (a, b) => (a.z != b.z) ? (a.z <=> b.z) : (a.index <=> b.index));
		for (let entry in ordered)
			Emit(tree, element.mChildren[entry.index], layer, effective, depth + 1, row);
	}
}
