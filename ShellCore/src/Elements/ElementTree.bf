namespace Shell.Elements;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Layout;

// The visual composition of one Widget (its "skin"). Owns the elements and the layer list.
//
// Mutation rules: Attach / Detach / Reparent / Remove are applied immediately when no traversal is active and are queued in the
// context's MutationQueue otherwise (Commit phase). Layout, rendering and input never see a tree that changes underneath them.
//
// Versions (dependency tracking, all monotonic counters):
//   mStructureVersion  elements added / removed / reordered, visibility, layer or composite changes -> render lists are rebuilt
//   mLayoutVersion     any layout input changed
//   mVisualVersion     anything that changes pixels (for diagnostics and caches)
class ElementTree
{
	public RuntimeContext mContext;
	public RuntimeObject mOwner;                // the Widget this tree belongs to
	public Element mRoot;
	public List<LayerDefinition> mLayers = new .() ~ DeleteContainerAndItems!(_);

	public int mStructureVersion;
	public int mLayoutVersion;
	public int mVisualVersion;

	// Last layout inputs (the layout system compares them to decide what to redo).
	public float mLayoutWidth = float.NaN;
	public float mLayoutHeight = float.NaN;
	public float mOriginX = float.NaN;
	public float mOriginY = float.NaN;

	// Cached render lists: layers with order <= 0 (before the widget's children) and order > 0 (after them).
	public List<RenderItem> mRenderPre = new .() ~ delete _;
	public List<RenderItem> mRenderPost = new .() ~ delete _;
	public bool bHasBackdrop;
	int mRenderListVersion = -1;
	int mRenderListRebuilds;
	public int mRebuildCount => mRenderListRebuilds;

	Dictionary<Handle, List<Element>> mRedirects = new .() ~ DeleteDictionaryAndValues!(_);
	bool bLinksDirty = true;

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

	public void BumpStructure()
	{
		mStructureVersion++;
		mVisualVersion++;
		bLinksDirty = true;
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
	// type == null selects the registered type of the kind (Shape, Text, Image ...).
	public Element CreateElement(ElementKind kind, TypeDescriptor type = null, StableId id = .sNone)
	{
		let element = new Element();
		element.mTree = this;
		element.mKind = kind;
		element.mType = (type != null) ? type : ElementTypes.TypeFor(kind);
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
			BumpStructure();
			child.InvalidateLayout();
			child.InvalidateState();
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

		BumpStructure();
		child.InvalidateLayout();
		child.InvalidateState();
		parent.InvalidateLayout();
	}

	void DetachNow(Element child)
	{
		if (child.mParent != null)
		{
			child.mParent.mChildren.Remove(child);
			child.mParent.InvalidateLayout();
			child.mParent = null;
		}
		else if (mRoot == child)
		{
			mRoot = null;
		}
		BumpStructure();
	}

	// ---- Layout hierarchy ---------------------------------------------------------------------------------------

	// Makes `parent` the layout parent of `element` (null = back to the owner). The element keeps its owner, lifetime and render
	// order; only measuring, arranging and its coordinate space change.
	public bool SetLayoutParent(Element element, Element parent)
	{
		if (parent == null)
		{
			element.mLayoutParent = Handle.sNone;
		}
		else
		{
			if (parent.mTree != this)
			{
				mContext.mDiagnostics.Error("ELM0022", "A layout parent must belong to the same element tree.", element.mStableId);
				return false;
			}
			for (var p = parent; p != null; p = GetLayoutParentElement(p))
			{
				if (p == element)
				{
					mContext.mDiagnostics.Error("ELM0021", "The layout parent would create a cycle in the layout hierarchy.", element.mStableId);
					return false;
				}
			}
			element.mLayoutParent = parent.mHandle;
			parent.InvalidateLayout();
		}
		BumpStructure();
		element.InvalidateLayout();
		element.InvalidateState();
		return true;
	}

	// The element that lays `element` out: its layout parent when that is valid, otherwise the owner. A layout parent that was
	// destroyed is reported once and the element falls back to its owner.
	public Element GetLayoutParentElement(Element element)
	{
		if (element.mLayoutParent.mIsValid)
		{
			let parent = mContext.Resolve<Element>(element.mLayoutParent);
			if (parent != null && parent.mIsAlive && parent.mTree == this)
				return parent;
			mContext.mDiagnostics.Warning("ELM0020", "The layout parent of this element no longer exists; it is laid out by its owner instead.", element.mStableId);
			element.mLayoutParent = Handle.sNone;
			BumpStructure();
		}
		return element.mParent;
	}

	void CollectRedirects(Element element)
	{
		if (element.mLayoutParent.mIsValid)
		{
			let target = GetLayoutParentElement(element);
			if (element.mLayoutParent.mIsValid && target != null)
			{
				if (mRedirects.TryGetValue(target.mHandle, let existing))
				{
					existing.Add(element);
				}
				else
				{
					let list = new List<Element>();
					list.Add(element);
					mRedirects[target.mHandle] = list;
				}
			}
		}
		for (let child in element.mChildren)
			CollectRedirects(child);
	}

	void EnsureLinks()
	{
		if (!bLinksDirty)
			return;
		bLinksDirty = false;
		for (let entry in mRedirects)
			delete entry.value;
		mRedirects.Clear();
		if (mRoot != null)
			CollectRedirects(mRoot);
	}

	// Elements laid out by `parent`: owned children without a layout parent (in order), then elements that name `parent` as their
	// layout parent. Hidden elements are included; the layout engine skips them.
	public void GetLayoutChildren(Element parent, List<Element> output)
	{
		EnsureLinks();
		for (let child in parent.mChildren)
		{
			if (!child.mLayoutParent.mIsValid && child.mIsAlive)
				output.Add(child);
		}
		if (mRedirects.TryGetValue(parent.mHandle, let list))
		{
			for (let element in list)
			{
				if (element.mIsAlive)
					output.Add(element);
			}
		}
	}

	// ---- Render lists -----------------------------------------------------------------------------------------------

	// Rebuilds mRenderPre / mRenderPost when the structure changed since they were built.
	public void EnsureRenderLists()
	{
		if (mRenderListVersion == mStructureVersion)
			return;
		mRenderListVersion = mStructureVersion;
		mRenderListRebuilds++;

		mRenderPre.Clear();
		mRenderPost.Clear();
		RenderListBuilder.Build(this, mRenderPre, int.MinValue, 0);
		RenderListBuilder.Build(this, mRenderPost, 1, int.MaxValue);
		bHasBackdrop = ContainsBackdrop(mRenderPre) || ContainsBackdrop(mRenderPost);
	}

	bool ContainsBackdrop(List<RenderItem> list)
	{
		for (let item in list)
		{
			if (item.mKind != .BeginGroup)
				continue;
			let element = mContext.Resolve<Element>(item.mElement);
			if (element != null && element.mComposite == .BackdropGroup)
				return true;
		}
		return false;
	}

	// ---- Layers -----------------------------------------------------------------------------------------------------

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
		BumpStructure();
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

	// Replaces the default layers (used when a skin brings its own layer list). Elements must not be assigned yet.
	public void ClearLayers()
	{
		mLayers.ClearAndDeleteItems();
		BumpStructure();
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
		BumpStructure();
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

	// Layer an element is drawn in: its own (if it still exists), otherwise the nearest ancestor's, otherwise Content.
	public StableId GetEffectiveLayer(Element element)
	{
		for (var e = element; e != null; e = e.mParent)
		{
			if (e.mLayer.mIsValid && FindLayer(e.mLayer) != null)
				return e.mLayer;
		}
		return FindLayerByRole(.Content).mId;
	}
}
