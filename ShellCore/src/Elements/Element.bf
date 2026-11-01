namespace Shell.Elements;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;

// One node of a visual composition. Three independent hierarchies meet here:
//   ownership  : mParent / mChildren (lifetime, transform and clip inheritance, hit-test order)
//   layout     : mLayoutParent (who measures / arranges this element; defaults to the owner)
//   render     : mLayer + mZIndex (draw order, see RenderListBuilder)
// Elements are visual only: they hold no interaction state. Everything dynamic comes from bindings that read the
// public state of the owning Widget (or globals, tokens, animation inputs).
class Element : RuntimeObject, IPropertyHost
{
	public ElementTree mTree;
	public ElementKind mKind;
	public TypeDescriptor mType;
	public PropertyStore mProperties;
	public String mName = new .() ~ delete _;

	// Ownership
	public Element mParent;
	public List<Element> mChildren = new .() ~ delete _;

	// Layout hierarchy (null = same as ownership parent)
	public Element mLayoutParent;

	// Render ordering
	public StableId mLayer;                 // none = inherit from the parent
	public int mZIndex;                     // order among siblings of the same layer
	public CompositeMode mComposite;
	public List<EffectDescriptor> mEffects = new .() ~ DeleteContainerAndItems!(_);

	// State-dependent composition: when the condition is false the element and its subtree are skipped by
	// layout, input and rendering (the subtree stays alive, so its bindings and animations keep their state).
	public BindingDescriptor mVisibleWhen;
	public Binding mVisibleBinding;
	public bool bConditionVisible = true;

	public List<Binding> mBindings = new .() ~ DeleteContainerAndItems!(_);

	public bool mIsVisible => (mProperties.Get(ElementTypes.sVisible).AsBool(true)) && bConditionVisible;

	protected override void OnInitialize()
	{
		mProperties = new PropertyStore(mType);
	}

	protected override void OnDestroy()
	{
		delete mProperties;
		mProperties = null;
		delete mVisibleBinding;
		mVisibleBinding = null;
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
			mParent = null;
		}
		else if (mTree != null && mTree.mRoot == this)
		{
			mTree.mRoot = null;
		}
	}

	// IPropertyHost
	public TypeDescriptor GetDescriptor() => mType;
	public Value GetProperty(PropertyDescriptor property) => mProperties.Get(property);

	public Result<void, PropertyError> SetProperty(PropertyDescriptor property, Value value)
	{
		if (mProperties.Set(property, value) case .Err(let error))
			return .Err(error);
		return .Ok;
	}

	public IObservable GetObservable(PropertyDescriptor property)
	{
		return mProperties.Observe(property);
	}
}
