namespace Shell.Elements;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Layout;
using Shell.Composition;
using Juno;

// One node of a visual composition. Three independent hierarchies meet here:
//   ownership  : mParent / mChildren - lifetime, visibility inheritance, render group membership, destruction
//   layout     : mLayoutParent (a Handle, stale handles fall back to the owner) - who measures / arranges this element and in whose
//                coordinate space it lives (transform and clip inheritance follow the layout parent)
//   render     : mLayer + mZIndex - draw order (see RenderListBuilder), independent of both hierarchies
// Elements are visual only: they hold no interaction state. Everything dynamic comes from bindings that read the public state of
// the owning Widget (or globals, tokens, animation inputs).
//
// Change tracking: every property carries Invalidation flags. Layout marks this element and its layout ancestors for measure and
// arrange (clean subtrees are skipped), Transform marks the world state (matrix, clip, opacity) of this subtree, Structure bumps
// the tree's structure version (cached render lists are rebuilt), Geometry drops the cached vector geometry.
class Element : RuntimeObject, IPropertyChangeListener
{
	public ElementTree mTree;
	public ElementKind mKind;
	public TypeDescriptor mType;
	public PropertyStore mProperties;
	public String mName = new .() ~ delete _;

	// Ownership
	public Element mParent;
	public List<Element> mChildren = new .() ~ delete _;

	// Layout hierarchy (none = same as the owner)
	public Handle mLayoutParent;

	// Render ordering
	public StableId mLayer;                 // none = inherit from the parent
	public int mZIndex;                     // order among siblings of the same layer
	public CompositeMode mComposite;
	public List<EffectDescriptor> mEffects = new .() ~ DeleteContainerAndItems!(_);

	// State-dependent composition. VisibleWhen keeps the subtree alive (bindings and animations keep their state), ExistsWhen creates
	// and destroys the template content (mTemplate = the node description the children are created from).
	public BindingDescriptor mVisibleWhen;
	public Binding mVisibleBinding;
	public bool bConditionVisible = true;
	public ElementNodeData mTemplate;       // not owned
	public Binding mExistsBinding;
	public bool bTemplateInstantiated;

	public List<Binding> mBindings = new .() ~ DeleteContainerAndItems!(_);

	// ---- Layout state (written by the LayoutEngine) ----
	LayoutParams mParams;
	bool bParamsDirty = true;
	public bool bMeasureDirty = true;
	public bool bArrangeDirty = true;
	public float mMeasuredWidth;            // desired size without margin
	public float mMeasuredHeight;
	public float mLastAvailableWidth = float.NaN;
	public float mLastAvailableHeight = float.NaN;
	public RectF mArranged;                 // box (margin removed) in the layout parent's local space
	public RectF mLastSlot;
	public bool bHasSlot;

	// ---- Render state (written by ElementStateUpdater, root space = window client coordinates) ----
	public Matrix3x2 mWorld = Matrix3x2.sIdentity;
	public RectF mWorldBounds;              // axis aligned bounds of the element box
	public RectF mClip;                     // effective clip (axis aligned approximation), valid when bHasClip
	public bool bHasClip;
	public float mEffectiveOpacity = 1;     // opacity for this element's own drawing
	public float mCompositeOpacity = 1;     // opacity applied when an isolated group is composited
	public bool bStateDirty = true;
	public bool bSubtreeStateDirty = true;

	// ---- Caches ----
	public PathGeometry mPathCache ~ delete _;
	public bool bGeometryDirty = true;

	public bool mIsVisible => mProperties.Get(ElementTypes.sVisible).AsBool(true) && bConditionVisible;

	public LayoutParams mLayoutParams
	{
		get
		{
			if (bParamsDirty)
			{
				mParams = LayoutParams.From(this);
				bParamsDirty = false;
			}
			return mParams;
		}
	}

	protected override void OnInitialize()
	{
		mProperties = new PropertyStore(mType, mContext.mStrings);
		mProperties.mListener = this;
	}

	protected override void OnDestroy()
	{
		if (mTree != null)
			mTree.BumpStructure();
		delete mProperties;
		mProperties = null;
		delete mVisibleBinding;
		mVisibleBinding = null;
		delete mExistsBinding;
		mExistsBinding = null;
	}

	protected override void OnDestroyRequested()
	{
		for (let child in mChildren)
			child.RequestDestroy();
	}

	public override void DetachFromOwner()
	{
		if (mParent != null)
		{
			mParent.mChildren.Remove(this);
			mParent.InvalidateLayout();
			mParent = null;
		}
		else if (mTree != null && mTree.mRoot == this)
		{
			mTree.mRoot = null;
		}
		if (mTree != null)
			mTree.BumpStructure();
	}

	// ---- IPropertyHost (members come from RuntimeObject) ----
	public override TypeDescriptor GetDescriptor() => mType;
	public override Value GetProperty(PropertyDescriptor property) => mProperties.Get(property);

	public override Result<void, PropertyError> SetProperty(PropertyDescriptor property, Value value)
	{
		if (mProperties.Set(property, value) case .Err(let error))
			return .Err(error);
		return .Ok;
	}

	public override IObservable GetObservable(PropertyDescriptor property)
	{
		return mProperties.Observe(property);
	}

	// ---- Invalidation ----

	public void OnPropertyChanged(PropertyStore store, PropertyDescriptor property, Value oldValue, Value newValue)
	{
		let flags = property.mInvalidates;
		if ((flags & .Layout) != 0)
		{
			bParamsDirty = true;
			InvalidateLayout();
		}
		if ((flags & .Transform) != 0)
			InvalidateState();
		if ((flags & .Structure) != 0 && mTree != null)
			mTree.BumpStructure();
		if ((flags & .Geometry) != 0)
			bGeometryDirty = true;
		if ((flags & (.Visual | .Text)) != 0 && mTree != null)
			mTree.mVisualVersion++;
	}

	// Measure and arrange are needed again for this element and everything that may size itself from it.
	public void InvalidateLayout()
	{
		bMeasureDirty = true;
		bArrangeDirty = true;
		bParamsDirty = true;
		if (mTree == null)
			return;
		var parent = mTree.GetLayoutParentElement(this);
		while (parent != null)
		{
			if (parent.bMeasureDirty && parent.bArrangeDirty)
				break;      // already marked, so its ancestors are too
			parent.bMeasureDirty = true;
			parent.bArrangeDirty = true;
			parent = mTree.GetLayoutParentElement(parent);
		}
		mTree.mLayoutVersion++;
	}

	// World matrix / clip / opacity of this element and its layout descendants must be recomputed.
	public void InvalidateState()
	{
		bStateDirty = true;
		bSubtreeStateDirty = true;
		if (mTree == null)
			return;
		var parent = mTree.GetLayoutParentElement(this);
		while (parent != null && !parent.bSubtreeStateDirty)
		{
			parent.bSubtreeStateDirty = true;
			parent = mTree.GetLayoutParentElement(parent);
		}
		mTree.mVisualVersion++;
	}

	public void SetZIndex(int zIndex)
	{
		if (mZIndex == zIndex)
			return;
		mZIndex = zIndex;
		if (mTree != null)
			mTree.BumpStructure();
	}

	public void SetComposite(CompositeMode mode)
	{
		if (mComposite == mode)
			return;
		mComposite = mode;
		if (mTree != null)
			mTree.BumpStructure();
	}

	// Parsed path geometry of a Path element (cached until PathData changes).
	public PathGeometry GetPathGeometry()
	{
		if (bGeometryDirty || mPathCache == null)
		{
			delete mPathCache;
			mPathCache = null;
			let data = mProperties.Get(ElementTypes.sPathData).AsString();
			if (!data.IsEmpty)
			{
				if (PathGeometry.Parse(data) case .Ok(let geometry))
					mPathCache = geometry;
				else
					mContext.mDiagnostics.Warning("ELM0030", "The path data of this element could not be parsed.", mStableId);
			}
			bGeometryDirty = false;
		}
		return mPathCache;
	}
}
