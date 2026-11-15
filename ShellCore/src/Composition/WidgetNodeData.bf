namespace Shell.Composition;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Elements;
using Shell.Blueprints;
using Shell.Animation;

// Saved description of one widget. A node is either a primitive widget (mTypeName set) or an instance of a UserWidget
// (mSourceDefinition set, mTypeName empty). Instances never copy the definition: they reference it by id and store only
// their overrides, so definition edits propagate to every instance.
class WidgetNodeData
{
	public StableId mId;
	public StringView mTypeName;
	public String mName = new .() ~ delete _;
	public StableId mSourceDefinition;      // UserWidget definition id
	public List<OverrideEntry> mOverrides = new .() ~ DeleteContainerAndItems!(_);
	public List<PropertyValueData> mProperties = new .() ~ delete _;
	public List<BindingDescriptor> mBindings = new .() ~ DeleteContainerAndItems!(_);
	public List<EventHookData> mEventHooks = new .() ~ delete _;
	public List<BlueprintAttachment> mBlueprints = new .() ~ delete _;
	public StableId mComponentStyle;
	public ElementTreeData mSkin ~ delete _;
	public List<WidgetNodeData> mChildren = new .() ~ DeleteContainerAndItems!(_);

	public bool mIsInstance => mSourceDefinition.mIsValid;
}
