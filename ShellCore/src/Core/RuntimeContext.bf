namespace Shell.Core;

using System;
using System.Collections;
using Shell.Reflection;
using Shell.Blueprints;
using Shell.Binding;
using Shell.Widgets;
using Shell.Input;

// Shared services of one running shell (editor preview, simulation, or the real shell each have their own context).
class RuntimeContext
{
	public IdGenerator mIds = new .() ~ delete _;
	public HandleTable<RuntimeObject> mObjects = new .() ~ delete _;
	public MutationQueue mMutations = new .() ~ delete _;
	public TraversalGuard mTraversal = new .() ~ delete _;
	public DiagnosticSink mDiagnostics = new .() ~ delete _;
	public StringPool mStrings = new .() ~ delete _;
	public TypeRegistry mTypes = new .() ~ delete _;
	public GlobalVariableStore mGlobals = new .() ~ delete _;
	public TimeSource mTime = new .() ~ delete _;
	public FrameContext mFrame;
	public IWidgetHost mWidgetHost;         // set by the widget runtime; widgets reach focus, capture and services through it

	List<IObjectDestroyListener> mDestroyListeners = new .() ~ delete _;

	public void AddDestroyListener(IObjectDestroyListener listener)
	{
		mDestroyListeners.Add(listener);
	}

	public void RemoveDestroyListener(IObjectDestroyListener listener)
	{
		mDestroyListeners.Remove(listener);
	}

	List<RuntimeObject> mPendingDestruction = new .() ~ delete _;
	Dictionary<StableId, Handle> mIdIndex = new .() ~ delete _;

	public Handle Register(RuntimeObject object)
	{
		return mObjects.Allocate(object);
	}

	// Returns null when the handle is stale or refers to an object of a different type.
	public T Resolve<T>(Handle handle) where T : RuntimeObject
	{
		let object = mObjects.Resolve(handle);
		return object as T;
	}

	// Indexes live objects by stable id. Ids are unique inside one composition scope; objects instantiated from the same
	// UserWidget definition share inner ids, so instantiation (Stage 3+) registers them under a scoped lookup instead of here.
	// A second registration of the same id keeps the first and reports a diagnostic.
	public void IndexStableId(RuntimeObject object)
	{
		if (mIdIndex.TryGetValue(object.mStableId, let existing) && mObjects.Resolve(existing) != null)
		{
			mDiagnostics.Warning("CORE0002", scope $"Stable id {object.mStableId} is used by more than one live object.", object.mStableId);
			return;
		}
		mIdIndex[object.mStableId] = object.mHandle;
	}

	public void UnindexStableId(RuntimeObject object)
	{
		if (mIdIndex.TryGetValue(object.mStableId, let handle) && handle == object.mHandle)
			mIdIndex.Remove(object.mStableId);
	}

	public RuntimeObject FindByStableId(StableId id)
	{
		if (mIdIndex.TryGetValue(id, let handle))
			return mObjects.Resolve(handle);
		return null;
	}

	public void QueueDestruction(RuntimeObject object)
	{
		mPendingDestruction.Add(object);
	}

	// Commit phase. Deletes objects whose destruction was requested (children before owners).
	public int FlushDestruction()
	{
		int count = 0;
		while (mPendingDestruction.Count > 0)
		{
			let batch = scope List<RuntimeObject>();
			batch.AddRange(mPendingDestruction);
			mPendingDestruction.Clear();

			for (let object in batch)
			{
				for (let listener in mDestroyListeners)
					listener.OnObjectDestroying(object);
				UnindexStableId(object);
				object.FinishDestroy();
				mObjects.Release(object.mHandle);
				delete object;
				count++;
			}
		}
		return count;
	}
}
