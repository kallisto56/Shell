namespace Shell.Composition;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Elements;
using Shell.Blueprints;
using Shell.Animation;

// Saved description of one element of a widget skin.
class ElementNodeData
{
	public StableId mId;
	public ElementKind mKind;
	public StringView mTypeName;            // element type descriptor ("Element", "Shape", "Text" ...)
	public String mName = new .() ~ delete _;
	public StableId mLayer;                 // none = inherit
	public int mZIndex;
	public CompositeMode mComposite;
	public List<PropertyValueData> mProperties = new .() ~ delete _;
	public List<BindingDescriptor> mBindings = new .() ~ DeleteContainerAndItems!(_);
	public BindingDescriptor mVisibleWhen ~ delete _;
	public List<EffectDescriptor> mEffects = new .() ~ DeleteContainerAndItems!(_);
	public List<ElementNodeData> mChildren = new .() ~ DeleteContainerAndItems!(_);   // ownership order
}
