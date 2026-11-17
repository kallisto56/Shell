namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

// The hierarchy of a composition as shown in the editor: widgets, UserWidget instances (expanded read-only through their definitions),
// skins and elements. Built from the saved description, so editing needs no running shell; live objects are found through the
// stable ids (runtime ids are Combine(instance id, node id), see UserWidgetHost).
class CompositionOutline
{
	public OutlineNode mRoot ~ delete _;
	const int cMaxDepth = 12;

	static public CompositionOutline Build(CompositionDefinition definition, CompositionRegistry registry)
	{
		let outline = new CompositionOutline();
		if (definition.mRoot != null)
		{
			let chain = scope List<StableId>();
			chain.Add(definition.mId);
			let prefix = scope List<StableId>();
			outline.mRoot = BuildWidget(definition.mRoot, null, prefix, false, 0, chain, registry);
			for (let member in definition.mExposed)
			{
				let target = outline.FindByPath(member.mInnerTarget);
				if (target != null)
					target.bExposed = true;
			}
		}
		return outline;
	}

	static OutlineNode BuildWidget(WidgetNodeData node, OutlineNode parent, List<StableId> prefix, bool readOnly, int depth,
		List<StableId> chain, CompositionRegistry registry)
	{
		let result = new OutlineNode();
		result.mParent = parent;
		result.mPath.AddRange(prefix);
		result.mPath.Add(node.mId);
		result.mName.Set(node.mName);
		result.mTypeName.Set(node.mTypeName);
		result.bReadOnly = readOnly;
		result.mOverrideCount = node.mOverrides.Count;

		if (node.mIsInstance)
		{
			result.mKind = .Instance;
			result.mDefinition = node.mSourceDefinition;
			let nested = registry.Find(node.mSourceDefinition);
			if (nested == null || chain.Contains(nested.mId) || depth >= cMaxDepth)
			{
				result.mKind = .Missing;
				return result;
			}
			result.mTypeName.Set(nested.mName);
			if (nested.mRoot != null)
			{
				chain.Add(nested.mId);
				let content = BuildWidget(nested.mRoot, result, result.mPath, true, depth + 1, chain, registry);
				chain.RemoveAt(chain.Count - 1);
				result.mChildren.Add(content);
			}
			return result;
		}

		result.mKind = .Widget;
		if (node.mSkin != null && node.mSkin.mRoot != null)
		{
			let skin = new OutlineNode();
			skin.mKind = .Skin;
			skin.mParent = result;
			skin.mName.Set("Skin");
			skin.bReadOnly = readOnly;
			result.mChildren.Add(skin);
			skin.mChildren.Add(BuildElement(node.mSkin.mRoot, skin, result.mPath, readOnly));
		}
		for (let child in node.mChildren)
			result.mChildren.Add(BuildWidget(child, result, prefix, readOnly, depth, chain, registry));
		return result;
	}

	static OutlineNode BuildElement(ElementNodeData element, OutlineNode parent, List<StableId> widgetPath, bool readOnly)
	{
		let result = new OutlineNode();
		result.mKind = .Element;
		result.mParent = parent;
		// Elements are addressed like widgets: the path of the owning widget's scope, then the element id.
		for (int i < widgetPath.Count - 1)
			result.mPath.Add(widgetPath[i]);
		result.mPath.Add(element.mId);
		result.mName.Set(element.mName);
		result.mTypeName.AppendF("{}", element.mKind);
		result.mLayer = element.mLayer;
		result.bEssential = element.bEssential;
		result.bReadOnly = readOnly;
		for (let child in element.mChildren)
			result.mChildren.Add(BuildElement(child, result, widgetPath, readOnly));
		return result;
	}

	// First node whose last path step is `id` (ids are unique inside the edited definition).
	public OutlineNode FindByPath(StableId id)
	{
		return mRoot == null ? null : Search(mRoot, id);
	}

	static OutlineNode Search(OutlineNode node, StableId id)
	{
		if (!node.bReadOnly && node.mKind != .Skin && node.mId == id)
			return node;
		for (let child in node.mChildren)
		{
			let found = Search(child, id);
			if (found != null)
				return found;
		}
		return null;
	}
}
