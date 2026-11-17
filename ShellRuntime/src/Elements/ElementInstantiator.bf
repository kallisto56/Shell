namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Elements;
using Shell.Widgets;
using Shell.Composition;

// Builds live elements from their saved description (ElementNodeData / ElementTreeData) and handles template content.
//
// Identity: elements created directly from a skin keep the saved ids. Elements created from a template (ExistsWhen) get
// StableId.Combine(owner id, template node id), so destroying and re-creating the content always yields the same ids (bindings,
// animation tracks and the editor selection keep working) and two instances of the same template under different owners never
// collide.
// Lifecycle: bindings, conditions and exists-conditions are registered with the BindingSystem and removed again when the element
// is destroyed; a template whose condition turns false destroys its children (at the next Commit) and keeps the element.
// All tree changes go through ElementTree, i.e. they are deferred while a traversal is running.
// The description (the model) must outlive the elements created from it: bindings refer to its descriptors.
class ElementInstantiator : IElementTemplateHost
{
	RuntimeContext mContext;
	BindingSystem mBindings;

	public this(RuntimeContext context, BindingSystem bindings)
	{
		mContext = context;
		mBindings = bindings;
		bindings.mTemplates = this;
		context.mTemplateHost = this;
	}

	public ~this()
	{
		if (mContext.mTemplateHost == this)
			mContext.mTemplateHost = null;
	}

	// Creates the elements and layers of a widget skin. The widget's element tree must be empty.
	public bool ApplySkin(Widget widget, ElementTreeData data, StableId scopeId = .sNone)
	{
		let tree = widget.mElements;
		widget.mSkinScope = scopeId;
		if (tree.mRoot != null)
		{
			mContext.mDiagnostics.Error("ELM0040", "The widget already has a skin; remove its elements first.", widget.mStableId);
			return false;
		}

		if (data.mLayers.Count > 0)
		{
			tree.ClearLayers();
			for (let layer in data.mLayers)
				tree.AddLayer(layer.mName, layer.mRole, layer.mOrder, layer.bEssential, layer.mId);
			if (tree.FindLayerByRole(.Content) == null)
			{
				mContext.mDiagnostics.Warning("ELM0043", "The skin has no Content layer; one was added.", widget.mStableId);
				tree.AddLayer("Content", .Content, 0, true);
			}
		}

		if (data.mRoot == null)
			return true;
		let root = CreateNode(tree, data.mRoot, scopeId);
		if (root == null)
			return false;
		tree.Attach(root, null);
		return true;
	}

	// Creates one element (and, unless it is a template, its children). Not attached to the tree yet.
	public Element CreateNode(ElementTree tree, ElementNodeData node, StableId scopeId)
	{
		var type = ElementTypes.TypeFor(node.mKind);
		if (!node.mTypeName.IsEmpty)
		{
			let found = mContext.mTypes.Find(node.mTypeName);
			if (found == null || !found.IsA(ElementTypes.sElement))
				mContext.mDiagnostics.Warning("ELM0041", scope $"Unknown element type '{node.mTypeName}'; the default type of its kind is used.", node.mId);
			else
				type = found;
		}

		let id = scopeId.mIsValid ? StableId.Combine(scopeId, node.mId) : node.mId;
		let element = tree.CreateElement(node.mKind, type, id);
		element.mName.Set(node.mName);
		element.bEssential = node.bEssential;
		element.mLayer = node.mLayer;
		element.SetZIndex(node.mZIndex);
		element.SetComposite(node.mComposite);

		for (let assignment in node.mProperties)
		{
			let property = type.FindProperty(assignment.mName);
			if (property == null)
			{
				mContext.mDiagnostics.Warning("ELM0042", scope $"Element type '{type.mName}' has no property '{assignment.mName}'.", id);
				continue;
			}
			if (element.SetProperty(property, assignment.mValue) case .Err(let error))
				mContext.mDiagnostics.Error("ELM0044", scope $"Property '{assignment.mName}' could not be set: {error}.", id);
		}

		for (let source in node.mEffects)
		{
			let effect = new EffectDescriptor();
			effect.mId = source.mId;
			effect.mKind = source.mKind;
			effect.mCustomName = source.mCustomName;
			effect.bEnabled = source.bEnabled;
			effect.mParameters.AddRange(source.mParameters);
			element.mEffects.Add(effect);
		}

		for (let binding in node.mBindings)
			mBindings.AddElementBinding(element, binding);
		if (node.mVisibleWhen != null)
			mBindings.SetCondition(element, node.mVisibleWhen);

		if (node.mExistsWhen != null)
		{
			element.mTemplate = node;       // children are created when the condition becomes true
			mBindings.AddExistsCondition(element, node.mExistsWhen);
		}
		else
		{
			for (let child in node.mChildren)
			{
				let created = CreateNode(tree, child, scopeId);
				if (created != null)
					tree.Attach(created, element);
			}
		}
		return element;
	}

	// IElementTemplateHost
	public void SetExists(Element element, bool exists)
	{
		if (exists == element.bTemplateInstantiated || element.mTemplate == null)
			return;

		let tree = element.mTree;
		if (exists)
		{
			// Content that was destroyed in the same frame must be gone before the same ids are created again.
			mContext.FlushDestruction();
			for (let child in element.mTemplate.mChildren)
			{
				let created = CreateNode(tree, child, element.mStableId);
				if (created != null)
					tree.Attach(created, element);
			}
			element.bTemplateInstantiated = true;
		}
		else
		{
			let children = scope List<Element>();
			children.AddRange(element.mChildren);
			for (let child in children)
				child.RequestDestroy();
			element.bTemplateInstantiated = false;
		}
		tree.BumpStructure();
	}
}
