namespace Shell.Composition;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Elements;
using Shell.Blueprints;
using Shell.Animation;

// Owns the definitions of a project and answers dependency questions: what does a definition use, is there a cycle,
// is anything missing. Loading and instantiation consult it so that cyclic or missing dependencies produce clear
// diagnostics and a visible placeholder instead of a crash or silently wrong output.
class CompositionRegistry
{
	Dictionary<StableId, CompositionDefinition> mDefinitions = new .() ~ delete _;
	List<CompositionDefinition> mOrdered = new .() ~ DeleteContainerAndItems!(_);

	public bool Add(CompositionDefinition definition, DiagnosticSink sink)
	{
		if (mDefinitions.ContainsKey(definition.mId))
		{
			sink.Error("CMP0001", scope $"A composition with id {definition.mId} already exists.", definition.mId);
			delete definition;
			return false;
		}
		mDefinitions[definition.mId] = definition;
		mOrdered.Add(definition);
		return true;
	}

	public CompositionDefinition Find(StableId id)
	{
		if (mDefinitions.TryGetValue(id, let definition))
			return definition;
		return null;
	}

	public void GetAll(List<CompositionDefinition> output)
	{
		output.AddRange(mOrdered);
	}

	// Ids of the definitions used (as nested instances) directly by `definition`, in tree order, without duplicates.
	public void GetDirectDependencies(CompositionDefinition definition, List<StableId> output)
	{
		if (definition.mRoot != null)
			Collect(definition.mRoot, output);
	}

	void Collect(WidgetNodeData node, List<StableId> output)
	{
		if (node.mIsInstance && !output.Contains(node.mSourceDefinition))
			output.Add(node.mSourceDefinition);
		for (let child in node.mChildren)
			Collect(child, output);
	}

	// True if `start` (transitively) contains an instance of itself. `path` receives the chain of ids when found.
	public bool FindCycle(StableId start, List<StableId> path)
	{
		let visiting = scope List<StableId>();
		return Visit(start, start, visiting, path);
	}

	bool Visit(StableId current, StableId target, List<StableId> visiting, List<StableId> path)
	{
		let definition = Find(current);
		if (definition == null)
			return false;

		visiting.Add(current);
		let dependencies = scope List<StableId>();
		GetDirectDependencies(definition, dependencies);
		for (let dependency in dependencies)
		{
			if (dependency == target)
			{
				path.AddRange(visiting);
				path.Add(dependency);
				return true;
			}
			if (visiting.Contains(dependency))
				continue;
			if (Visit(dependency, target, visiting, path))
				return true;
		}
		visiting.RemoveAt(visiting.Count - 1);
		return false;
	}

	// Definitions that are referenced but not present (not loaded, deleted, wrong package).
	public void FindMissing(CompositionDefinition definition, List<StableId> missing)
	{
		let dependencies = scope List<StableId>();
		GetDirectDependencies(definition, dependencies);
		for (let dependency in dependencies)
		{
			if (Find(dependency) == null)
				missing.Add(dependency);
		}
	}

	// Definitions whose instances must be refreshed when `changed` was edited: everything that depends on it,
	// directly or transitively (dependents first-level, then up).
	public void GetDependents(StableId changed, List<StableId> output)
	{
		bool bAdded = true;
		output.Add(changed);
		while (bAdded)
		{
			bAdded = false;
			for (let definition in mOrdered)
			{
				if (output.Contains(definition.mId))
					continue;
				let dependencies = scope List<StableId>();
				GetDirectDependencies(definition, dependencies);
				for (let dependency in dependencies)
				{
					if (output.Contains(dependency))
					{
						output.Add(definition.mId);
						bAdded = true;
						break;
					}
				}
			}
		}
		output.Remove(changed);
	}
}
