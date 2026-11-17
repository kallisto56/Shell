namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

// Collects the binding descriptors of a composition (widget bindings, element bindings, visibility and exists conditions) together with
// the id of the object that owns them. The descriptors are not owned by the result.
static class BindingScanner
{
	static public void Collect(WidgetNodeData root, List<(BindingDescriptor binding, StableId owner)> output)
	{
		for (let binding in root.mBindings)
			output.Add((binding, root.mId));
		if (root.mSkin != null && root.mSkin.mRoot != null)
			CollectElement(root.mSkin.mRoot, output);
		for (let child in root.mChildren)
			Collect(child, output);
	}

	static void CollectElement(ElementNodeData element, List<(BindingDescriptor binding, StableId owner)> output)
	{
		for (let binding in element.mBindings)
			output.Add((binding, element.mId));
		if (element.mVisibleWhen != null)
			output.Add((element.mVisibleWhen, element.mId));
		if (element.mExistsWhen != null)
			output.Add((element.mExistsWhen, element.mId));
		for (let child in element.mChildren)
			CollectElement(child, output);
	}
}
