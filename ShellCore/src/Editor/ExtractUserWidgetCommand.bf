namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

// The change set of "extract UserWidget": the selected widgets move into a new definition, an instance node takes their place in the
// parent, and everything that referred to the moved objects from outside is redirected through exposed members. Built by
// UserWidgetExtractor.Prepare; Do / Undo are exact inverses (ownership of nodes moves back and forth between the parent, the new
// definition and this command).
class ExtractUserWidgetCommand : DefinitionCommand
{
	public struct BindingRewrite
	{
		public BindingDescriptor mBinding;
		public StableId mOldTarget;
		public StringView mOldMember;
		public StableId mNewTarget;
		public StringView mNewMember;
	}

	public struct ExposedRewrite
	{
		public ExposedMember mMember;
		public StableId mOldTarget;
		public StringView mOldMember;
		public StableId mNewTarget;
		public StringView mNewMember;
	}

	public struct BoundsChange
	{
		public WidgetNodeData mNode;
		public int mIndex;              // index in mProperties
		public Value mOld;
		public Value mNew;
	}

	public CompositionRegistry mRegistry;
	public CompositionDefinition mNewDefinition;    // owned until applied
	public WidgetNodeData mInstance;                // owned until applied
	public WidgetNodeData mGroupRoot;               // several widgets: the container that becomes the root (owned by the command until applied)
	public WidgetNodeData mParent;
	public List<WidgetNodeData> mMoved = new .() ~ delete _;
	public List<int> mOldIndices = new .() ~ delete _;
	public List<BindingRewrite> mBindingRewrites = new .() ~ delete _;
	public List<ExposedRewrite> mExposedRewrites = new .() ~ delete _;
	public List<BoundsChange> mBoundsChanges = new .() ~ delete _;
	public Value mInstanceBounds;
	public bool bHasInstanceBounds;
	bool bApplied;

	public this(DefinitionEditSession session, CompositionRegistry registry) : base(session, "Extract UserWidget")
	{
		mRegistry = registry;
	}

	public ~this()
	{
		if (!bApplied)
		{
			delete mNewDefinition;
			delete mInstance;
			delete mGroupRoot;
		}
	}

	protected override void Apply()
	{
		// 1. the moved nodes leave the parent; the instance takes the first one's place
		for (let node in mMoved)
			mParent.mChildren.Remove(node);
		mParent.mChildren.Insert(Math.Clamp(mOldIndices[0], 0, mParent.mChildren.Count), mInstance);

		// 2. the new definition gets them
		if (mGroupRoot != null)
		{
			for (let node in mMoved)
				mGroupRoot.mChildren.Add(node);
			mNewDefinition.mRoot = mGroupRoot;
		}
		else
		{
			mNewDefinition.mRoot = mMoved[0];
		}

		// 3. layout: the instance takes the old position, the content starts at the origin
		for (let change in mBoundsChanges)
		{
			var property = change.mNode.mProperties[change.mIndex];
			property.mValue = change.mNew;
			change.mNode.mProperties[change.mIndex] = property;
		}

		// 4. references from outside now go through the instance
		for (let rewrite in mBindingRewrites)
		{
			rewrite.mBinding.mSource.mTarget = rewrite.mNewTarget;
			rewrite.mBinding.mSource.mMember = rewrite.mNewMember;
		}
		for (let rewrite in mExposedRewrites)
		{
			rewrite.mMember.mInnerTarget = rewrite.mNewTarget;
			rewrite.mMember.mInnerMember = rewrite.mNewMember;
		}

		mRegistry.AddOwned(mNewDefinition);
		bApplied = true;
	}

	protected override void Revert()
	{
		mRegistry.Remove(mNewDefinition.mId);

		for (let rewrite in mExposedRewrites)
		{
			rewrite.mMember.mInnerTarget = rewrite.mOldTarget;
			rewrite.mMember.mInnerMember = rewrite.mOldMember;
		}
		for (let rewrite in mBindingRewrites)
		{
			rewrite.mBinding.mSource.mTarget = rewrite.mOldTarget;
			rewrite.mBinding.mSource.mMember = rewrite.mOldMember;
		}
		for (let change in mBoundsChanges)
		{
			var property = change.mNode.mProperties[change.mIndex];
			property.mValue = change.mOld;
			change.mNode.mProperties[change.mIndex] = property;
		}

		mNewDefinition.mRoot = null;
		if (mGroupRoot != null)
			mGroupRoot.mChildren.Clear();

		mParent.mChildren.Remove(mInstance);
		for (int i < mMoved.Count)
			mParent.mChildren.Insert(Math.Clamp(mOldIndices[i], 0, mParent.mChildren.Count), mMoved[i]);
		bApplied = false;
	}
}
