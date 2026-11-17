namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Elements;
using Shell.Widgets;
using Shell.Composition;
using Shell.Platform;

// Creates UserWidget instances and keeps them in sync with their definitions.
//
// Instances:   CreateInstance builds the hidden content from the definition (scoped ids), links the exposed interface and applies the
//              instance's property values and overrides, in that order.
// Propagation: the host (a Commit phase system) compares every instance's built revision with its definition's revision. When a definition
//              changed, ALL its instances are rebuilt in the same Commit, outer instances before inner ones, so the frame that follows
//              sees one consistent state. A rebuild keeps the instance (identity, parent, bounds, bindings, subscribers), replaces the
//              content, re-applies overrides and re-links; overrides whose target no longer exists stay in the data and are reported
//              (UWD0030). Runtime state inside the content (focus, typed text) starts over.
//              Exposed interface changes swap the instance's property store; bindings reading from it are detached and re-attached.
// Safety:      missing definitions and dependency cycles produce a visible placeholder instance (IsMissing) and a diagnostic; instance
//              nesting is limited to mMaxDepth.
class UserWidgetHost : IRuntimeSystem, IObjectDestroyListener
{
	RuntimeContext mContext;
	public CompositionRegistry mRegistry;
	public UserWidgetTypeFactory mTypes;
	public CompositionInstantiator mInstantiator;
	public BindingSystem mBindings;
	public int mMaxDepth = 16;
	public int mOrder;
	public int mRebuilt;                    // instances rebuilt in the last frame

	List<Handle> mInstances = new .() ~ delete _;
	HashSet<String> mReported = new .() ~ DeleteContainerAndItems!(_);

	public this(RuntimeContext context, UserWidgetTypeFactory types, BindingSystem bindings)
	{
		mContext = context;
		mTypes = types;
		mBindings = bindings;
		context.AddDestroyListener(this);
	}

	public ~this()
	{
		mContext.RemoveDestroyListener(this);
	}

	public UpdatePhase GetPhase() => .Commit;
	public int GetOrder() => mOrder;

	void ReportOnce(StringView code, StringView message, StableId source)
	{
		let key = scope String();
		key.AppendF("{}|{}|{}", code, message, source);
		if (mReported.Contains(key))
			return;
		mReported.Add(new String(key));
		mContext.mDiagnostics.Warning(code, message, source);
	}

	public void OnObjectDestroying(RuntimeObject object)
	{
		mInstances.Remove(object.mHandle);
		for (let handle in mInstances)
		{
			let instance = mContext.Resolve<UserWidget>(handle);
			if (instance != null)
				instance.OnTargetDestroying(object.mHandle);
		}
	}

	// ---- creation ----

	public UserWidget CreateInstance(WidgetNodeData node, Widget parent, StableId scopeId, int depth)
	{
		let instance = new UserWidget();
		instance.mHost = this;
		instance.mNode = node;
		instance.mDefinitionId = node.mSourceDefinition;
		instance.mDepth = depth;

		let definition = FindUsable(node.mSourceDefinition, depth, node.mId);
		if (definition != null)
			instance.mType = mTypes.GetType(definition);

		let id = scopeId.mIsValid ? StableId.Combine(scopeId, node.mId) : node.mId;
		instance.Initialize(mContext, id);
		instance.mComponentStyle = node.mComponentStyle;
		if (!node.mName.IsEmpty)
			instance.SetProperty(WidgetTypes.sName, Value.FromString(mContext.mStrings.InternTransient(node.mName)));
		instance.Activate();
		if (parent != null)
			parent.AddChild(instance);
		mInstances.Add(instance.mHandle);

		Build(instance, definition);
		instance.Link(definition);
		ApplyInstanceValues(instance);
		ApplyOverrides(instance);
		return instance;
	}

	// The definition if it exists, does not create a cycle and the nesting depth is allowed; otherwise null (placeholder) and a diagnostic.
	CompositionDefinition FindUsable(StableId definitionId, int depth, StableId source)
	{
		if (mRegistry == null)
			return null;
		let definition = mRegistry.Find(definitionId);
		if (definition == null)
		{
			ReportOnce("UWD0001", scope $"The UserWidget definition {definitionId} does not exist; a placeholder is shown.", source);
			return null;
		}
		let path = scope List<StableId>();
		if (mRegistry.FindCycle(definitionId, path))
		{
			ReportOnce("UWD0002", scope $"The UserWidget '{definition.mName}' contains itself (directly or through other UserWidgets); a placeholder is shown.", source);
			return null;
		}
		if (depth > mMaxDepth)
		{
			ReportOnce("UWD0003", scope $"UserWidgets are nested deeper than {mMaxDepth} levels; a placeholder is shown.", source);
			return null;
		}
		return definition;
	}

	// Creates the content (or marks the instance as a placeholder).
	void Build(UserWidget instance, CompositionDefinition definition)
	{
		instance.bMissing = (definition == null);
		instance.mProperties.SetInternal(UserWidget.sIsMissing, Value.FromBool(instance.bMissing));
		if (definition == null || definition.mRoot == null)
			return;

		instance.mBuiltRevision = definition.mRevision;
		instance.mProperties.SetInternal(UserWidget.sDefinitionRevision, Value.FromInt((int64)definition.mRevision));
		instance.mContent = mInstantiator.InstantiateNode(definition.mRoot, instance, instance.mStableId, instance.mDepth + 1);

		// A new instance takes the authored size of the definition root when it has none of its own.
		if (instance.mContent != null)
		{
			let own = instance.mBounds;
			let authored = instance.mContent.mBounds;
			if (own.mWidth <= 0 && own.mHeight <= 0)
				instance.SetBounds(RectF(own.mX, own.mY, authored.mWidth, authored.mHeight));
			instance.FitContent();
		}
	}

	// Property values saved on the instance node (exposed properties are written through to the inner targets).
	void ApplyInstanceValues(UserWidget instance)
	{
		let type = instance.GetDescriptor();
		for (let assignment in instance.mNode.mProperties)
		{
			let property = type.FindProperty(assignment.mName);
			if (property == null)
			{
				ReportOnce("UWD0031", scope $"The instance has a saved value for '{assignment.mName}', which the definition no longer exposes.", instance.mStableId);
				continue;
			}
			if (instance.SetProperty(property, assignment.mValue) case .Err(let error))
				ReportOnce("UWD0032", scope $"The saved value for '{assignment.mName}' could not be applied: {error}.", instance.mStableId);
		}
	}

	// Overrides address inner objects by a path of authored ids (nested instances ..., target); the runtime id of the target is the fold
	// of StableId.Combine along the path, starting at the instance. Orphaned entries are kept and reported.
	void ApplyOverrides(UserWidget instance)
	{
		if (instance.bMissing)
			return;
		for (let entry in instance.mNode.mOverrides)
		{
			var id = instance.mStableId;
			for (let step in entry.mPath)
				id = StableId.Combine(id, step);

			let target = mContext.FindByStableId(id);
			if (target == null || entry.mPath.Count == 0)
			{
				ReportOnce("UWD0030", scope $"An override of '{entry.mProperty}' targets an object that no longer exists in the definition (kept, not applied).", instance.mStableId);
				continue;
			}
			let property = target.GetDescriptor().FindProperty(entry.mProperty);
			if (property == null)
			{
				ReportOnce("UWD0033", scope $"An override targets the unknown property '{entry.mProperty}'.", instance.mStableId);
				continue;
			}
			if (target.SetProperty(property, entry.mValue) case .Err(let error))
				ReportOnce("UWD0034", scope $"The override of '{entry.mProperty}' could not be applied: {error}.", instance.mStableId);
		}
	}

	// ---- propagation ----

	// Explicit notification after an edit (the polling in Update would notice the revision change as well).
	public void NotifyDefinitionChanged(StableId definitionId)
	{
		// Nothing to store: Update compares revisions. Kept as an API point for editors that want to be explicit.
	}

	bool NeedsRebuild(UserWidget instance)
	{
		let definition = (mRegistry != null) ? mRegistry.Find(instance.mDefinitionId) : null;
		if (definition == null)
			return !instance.bMissing;
		if (instance.bMissing)
			return true;
		return definition.mRevision != instance.mBuiltRevision;
	}

	public void Update(FrameContext frame)
	{
		mRebuilt = 0;
		let all = scope List<UserWidget>();
		let stale = scope List<UserWidget>();
		for (let handle in mInstances)
		{
			let instance = mContext.Resolve<UserWidget>(handle);
			if (instance == null || !instance.mIsAlive)
				continue;
			all.Add(instance);
			if (NeedsRebuild(instance))
				stale.Add(instance);
		}
		if (stale.Count == 0)
			return;

		// 1. drop every link first: rebuilding replaces observables and subscriptions they point into
		for (let instance in all)
			instance.Unlink();

		// 2. rebuild outer instances before inner ones (rebuilding an outer one destroys the inner ones inside it)
		stale.Sort(scope (a, b) => a.mDepth <=> b.mDepth);
		for (let instance in stale)
		{
			if (!instance.mIsAlive)
				continue;
			Rebuild(instance);
			mRebuilt++;
		}

		// 3. link again, inner instances first so outer mirrors read up-to-date values
		let alive = scope List<UserWidget>();
		for (let handle in mInstances)
		{
			let instance = mContext.Resolve<UserWidget>(handle);
			if (instance != null && instance.mIsAlive)
				alive.Add(instance);
		}
		alive.Sort(scope (a, b) => b.mDepth <=> a.mDepth);
		for (let instance in alive)
		{
			let definition = (mRegistry != null) ? mRegistry.Find(instance.mDefinitionId) : null;
			if (!instance.bMissing)
				instance.Link(definition);
		}
		for (let instance in alive)
		{
			if (stale.Contains(instance))
			{
				ApplyInstanceValues(instance);
				ApplyOverrides(instance);
			}
		}
	}

	void Rebuild(UserWidget instance)
	{
		let definition = FindUsable(instance.mDefinitionId, instance.mDepth, instance.mStableId);

		// The exposed interface may have changed: switch the type (and keep bindings that read from the instance working).
		let newType = (definition != null) ? mTypes.GetType(definition) : UserWidget.sBaseType;
		if (newType != instance.GetDescriptor())
		{
			let taken = scope List<Binding>();
			mBindings.TakeSourcesOf(instance, taken);
			instance.SwapType(newType);
			mBindings.RestoreSources(taken);
		}

		if (instance.mContent != null)
		{
			instance.mContent.RequestDestroy();
			instance.mContent = null;
			mContext.FlushDestruction();        // ids must be free before the same ids are created again
		}
		Build(instance, definition);
	}
}
