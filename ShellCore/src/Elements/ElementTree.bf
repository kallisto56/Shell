namespace Shell.Elements;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;

// The visual composition of one Widget (its "skin"). Owns the elements and the layer list.
//
// Mutation rules: Attach / Detach / Reorder / Remove are applied immediately when no traversal is active and are
// queued in the context's MutationQueue otherwise (Commit phase). Layout, rendering and input never see a tree that
// changes underneath them.
class ElementTree
{
	public RuntimeContext mContext;
	public RuntimeObject mOwner;                // the Widget this tree belongs to
	public Element mRoot;
	public List<LayerDefinition> mLayers = new .() ~ DeleteContainerAndItems!(_);

	class AttachMutation : Mutation
	{
		public Handle mChild;
		public Handle mParent;
		public int mIndex;

		public override void Apply(RuntimeContext context)
		{
			let child = context.Resolve<Element>(mChild);
			let parent = context.Resolve<Element>(mParent);
			if (child == null || parent == null || !child.mIsAlive || !parent.mIsAlive)
				return;     // destroyed in the meantime: nothing to attach
			child.mTree.AttachNow(child, parent, mIndex);
		}
	}

	class DetachMutation : Mutation
	{
		public Handle mChild;

		public override void Apply(RuntimeContext context)
		{
			let child = context.Resolve<Element>(mChild);
			if (child != null)
				child.mTree.DetachNow(child);
		}
	}

	public this(RuntimeContext context, RuntimeObject owner)
	{
		mContext = context;
		mOwner = owner;
		EnsureDefaultLayers();
	}

	// Underlay / Content / Overlay always exist.
	void EnsureDefaultLayers()
	{
		AddLayer("Underlay", .Underlay, -100, false);
		AddLayer("Content", .Content, 0, true);
		AddLayer("Overlay", .Overlay, 100, false);
	}

	// ---- Elements -------------------------------------------------------------------------------------------

	// Creates an element. It is initialized and registered but not attached to the tree yet.
	public Element CreateElement(ElementKind kind, TypeDescriptor type, StableId id = .sNone)
	{
		let element = new Element();
		element.mTree = this;
		element.mKind = kind;
		element.mType = type;
		element.Initialize(mContext, id);
		element.Activate();
		return element;
	}

	// parent == null makes the element the root (only allowed while the tree has no root).
	public void Attach(Element child, Element parent, int index = -1)
	{
		if (mContext.mTraversal.mIsTraversing)
		{
			let mutation = new AttachMutation();
			mutation.mChild = child.mHandle;
			mutation.mParent = (parent != null) ? parent.mHandle : Handle.sNone;
			mutation.mIndex = index;
			mContext.mMutations.Defer(mutation);
			return;
		}
		AttachNow(child, parent, index);
	}

	public void Detach(Element child)
	{
		if (mContext.mTraversal.mIsTraversing)
		{
			let mutation = new DetachMutation();
			mutation.mChild = child.mHandle;
			mContext.mMutations.Defer(mutation);
			return;
		}
		DetachNow(child);
	}

	// Moves to a new parent (identity, bindings and animation state of the subtree are preserved).
	public void Reparent(Element child, Element newParent, int index = -1)
	{
		Detach(child);
		Attach(child, newParent, index);
	}

	// Destroys the element and everything it owns (at the next Commit).
	public void Remove(Element element)
	{
		element.RequestDestroy();
	}

	void AttachNow(Element child, Element parent, int index)
	{
		if (child.mParent != null)
			DetachNow(child);

		if (parent == null)
		{
			Runtime.Assert(mRoot == null, "ElementTree already has a root");
			mRoot = child;
			child.mOwner = mOwner;
			return;
		}

		// Guard against cycles: the parent must not be a descendant of the child.
		for (var ancestor = parent; ancestor != null; ancestor = ancestor.mParent)
		{
			if (ancestor == child)
			{
				mContext.mDiagnostics.Error("ELM0001", "An element cannot be attached below itself.", child.mStableId);
				return;
			}
		}

		child.mParent = parent;
		child.mOwner = parent;
		if (index < 0 || index >= parent.mChildren.Count)
			parent.mChildren.Add(child);
		else
			parent.mChildren.Insert(index, child);
	}

	void DetachNow(Element child)
	{
		if (child.mParent != null)
		{
			child.mParent.mChildren.Remove(child);
			child.mParent = null;
		}
		else if (mRoot == child)
		{
			mRoot = null;
		}
	}

	// ---- Layers -----------------------------------------------------------------------------------------------

	public LayerDefinition AddLayer(StringView name, LayerRole role, int order, bool essential, StableId id = .sNone)
	{
		let layer = new LayerDefinition();
		layer.mId = id.mIsValid ? id : mContext.mIds.Next();
		layer.mName.Set(name);
		layer.mRole = role;
		layer.mOrder = order;
		layer.bEssential = essential;
		mLayers.Add(layer);
		mLayers.Sort(scope (a, b) => a.mOrder <=> b.mOrder);    // stable for equal orders
		return layer;
	}

	public LayerDefinition FindLayer(StableId id)
	{
		for (let layer in mLayers)
		{
			if (layer.mId == id)
				return layer;
		}
		return null;
	}

	public LayerDefinition FindLayerByRole(LayerRole role)
	{
		for (let layer in mLayers)
		{
			if (layer.mRole == role)
				return layer;
		}
		return null;
	}

	// Essential layers cannot be removed. Elements of a removed layer move to the Content layer.
	public bool RemoveLayer(StableId id)
	{
		let layer = FindLayer(id);
		if (layer == null || layer.bEssential)
			return false;

		let content = FindLayerByRole(.Content);
		ReassignLayer(mRoot, id, content.mId);
		mLayers.Remove(layer);
		delete layer;
		return true;
	}

	void ReassignLayer(Element element, StableId from, StableId to)
	{
		if (element == null)
			return;
		if (element.mLayer == from)
			element.mLayer = to;
		for (let child in element.mChildren)
			ReassignLayer(child, from, to);
	}

	// Layer an element is drawn in: its own, otherwise the nearest ancestor's, otherwise Content.
	public StableId GetEffectiveLayer(Element element)
	{
		for (var e = element; e != null; e = e.mParent)
		{
			if (e.mLayer.mIsValid)
				return e.mLayer;
		}
		return FindLayerByRole(.Content).mId;
	}
}
