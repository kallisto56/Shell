namespace Shell.Core;

using System;

// Base of everything that lives in a running shell (Widget, Element, Blueprint instance, animation controller ...).
//
// Ownership: every object has exactly one owner (a parent object, or the context for roots) and the owner is responsible
// for its memory. References between objects are Handles, never raw pointers, so a destroyed object can be detected.
//
// Destruction protocol:
//   1. RequestDestroy() marks the object (and, children first, everything it owns) as Deactivating. Traversals skip
//      Deactivating objects, handles keep resolving.
//   2. RuntimeContext.FlushDestruction() (Commit phase) detaches the object from its owner, calls OnDestroy,
//      releases the handle and deletes it.
abstract class RuntimeObject
{
	public RuntimeContext mContext;
	public Handle mHandle;
	public StableId mStableId;
	public LifecycleState mState = .Created;
	public RuntimeObject mOwner;

	public bool mIsAlive => mState == .Initialized || mState == .Active;

	// Hooks for subclasses.
	protected virtual void OnInitialize() { }
	protected virtual void OnActivate() { }
	protected virtual void OnDeactivate() { }
	protected virtual void OnDestroy() { }
	// Called from RequestDestroy: containers request destruction of their children here.
	protected virtual void OnDestroyRequested() { }
	// Called by the context during flush: remove this object from the owner's child list.
	public virtual void DetachFromOwner() { }

	// stableId: pass StableId.sNone for a freshly created object (a new id is generated); loaders pass the saved id.
	public void Initialize(RuntimeContext context, StableId stableId)
	{
		Runtime.Assert(mState == .Created, "Object initialized twice");
		mContext = context;
		mHandle = context.Register(this);
		mStableId = stableId.mIsValid ? stableId : context.mIds.Next();
		mState = .Initialized;
		context.IndexStableId(this);
		OnInitialize();
	}

	public void Activate()
	{
		if (mState != .Initialized)
			return;
		mState = .Active;
		OnActivate();
	}

	public void RequestDestroy()
	{
		if (mState == .Deactivating || mState == .Destroyed)
			return;

		let wasActive = (mState == .Active);
		mState = .Deactivating;
		if (wasActive)
			OnDeactivate();
		OnDestroyRequested();               // children first ...
		mContext.QueueDestruction(this);    // ... then this object
	}

	// Called by RuntimeContext.FlushDestruction only.
	public void FinishDestroy()
	{
		DetachFromOwner();
		OnDestroy();
		mState = .Destroyed;
	}
}
