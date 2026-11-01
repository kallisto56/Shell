namespace Shell.Composition;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Elements;
using Shell.Blueprints;
using Shell.Animation;

// A UserWidget definition: a reusable composition authored directly in the editor. It is the only reuse mechanism in the
// product (there is no separate Symbol / Prefab type): any composition can be saved or extracted as one.
// mRevision increases with every committed edit; instances compare it to detect stale state.
class CompositionDefinition
{
	public StableId mId;
	public String mName = new .() ~ delete _;
	public uint32 mRevision;
	public WidgetNodeData mRoot ~ delete _;
	public List<BlueprintAsset> mBlueprints = new .() ~ DeleteContainerAndItems!(_);
	public List<AnimationClip> mClips = new .() ~ DeleteContainerAndItems!(_);
	public List<StateMachineDef> mStateMachines = new .() ~ DeleteContainerAndItems!(_);
	public List<ExposedMember> mExposed = new .() ~ DeleteContainerAndItems!(_);

	public ExposedMember FindExposed(StringView publicName, ExposedKind kind)
	{
		for (let member in mExposed)
		{
			if (member.mKind == kind && member.mPublicName == publicName)
				return member;
		}
		return null;
	}
}
