namespace Shell.Elements;

using System;
using System.Collections;
using Shell.Core;

// Turns an ElementTree into a flat, ordered list of render items. Pure function of the tree (read-only phase).
//
// Order: layers by ascending order; inside a layer, elements in ownership (depth-first) order, siblings sorted by
// ZIndex (stable). An element whose effective layer differs from the one being emitted is skipped for that pass but
// its descendants are still visited, so a child can be drawn in the Overlay while its parent stays in Content.
// Groups wrap the element and its descendants that are in the same layer; descendants in other layers are drawn in
// their layer, outside of the group.
// Hidden elements (Visible = false or condition false) hide their whole subtree in every layer.
static class RenderListBuilder
{
	static public void Build(ElementTree tree, List<RenderItem> output)
	{
		if (tree.mRoot == null)
			return;
		for (let layer in tree.mLayers)
			Emit(tree, tree.mRoot, layer.mId, tree.GetEffectiveLayer(tree.mRoot), 0, output);
	}

	static void Emit(ElementTree tree, Element element, StableId layer, StableId inheritedLayer, int depth, List<RenderItem> output)
	{
		if (!element.mIsAlive || !element.mIsVisible)
			return;

		let effective = element.mLayer.mIsValid ? element.mLayer : inheritedLayer;
		let bHere = (effective == layer);

		RenderItem item = default;
		item.mElement = element.mHandle;
		item.mDepth = depth;

		let bGroup = bHere && element.mComposite != .None;
		if (bGroup)
		{
			item.mKind = .BeginGroup;
			output.Add(item);
		}
		if (bHere)
		{
			item.mKind = .Draw;
			output.Add(item);
		}

		// Siblings sorted by ZIndex; List.Sort is not guaranteed stable, so sort a copy by (zIndex, original index).
		let ordered = scope List<(int z, int index)>();
		for (int i < element.mChildren.Count)
			ordered.Add((element.mChildren[i].mZIndex, i));
		ordered.Sort(scope (a, b) => (a.z != b.z) ? (a.z <=> b.z) : (a.index <=> b.index));

		for (let entry in ordered)
			Emit(tree, element.mChildren[entry.index], layer, effective, depth + 1, output);

		if (bGroup)
		{
			item.mKind = .EndGroup;
			output.Add(item);
		}
	}
}
