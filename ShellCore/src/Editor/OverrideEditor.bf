namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

// Per-instance overrides of a UserWidget instance node.
//
// An override addresses an object inside the instance by a path of authored ids: [nested instance ids ..., target id]. At run time the
// path is folded with StableId.Combine starting at the instance (UserWidgetHost.ApplyOverrides). Overrides rank above the definition and
// above styles (layer InstanceOverride) and below animation and Blueprints. An override whose target disappears after a definition edit is
// kept and reported, never silently dropped.
class OverrideEditor
{
	DefinitionEditSession mSession;
	CompositionRegistry mRegistry;
	CommandStack mStack;

	public this(DefinitionEditSession session, CompositionRegistry registry, CommandStack stack)
	{
		mSession = session;
		mRegistry = registry;
		mStack = stack;
	}

	// The path must walk through nested instances and end at an object that exists in the last definition.
	public EditError ValidatePath(WidgetNodeData instance, List<StableId> path)
	{
		if (!instance.mIsInstance || path.Count == 0)
			return .InvalidTarget;
		var definition = mRegistry.Find(instance.mSourceDefinition);
		for (int i < path.Count)
		{
			if (definition == null || definition.mRoot == null)
				return .NotFound;
			let index = DefinitionIndex.Build(definition.mRoot);
			defer delete index;
			let found = index.Find(path[i]);
			if (found case .Err)
				return .NotFound;
			if (i == path.Count - 1)
				return .None;
			let entry = found.Value;
			if (entry.mWidget == null || !entry.mWidget.mIsInstance)
				return .InvalidTarget;
			definition = mRegistry.Find(entry.mWidget.mSourceDefinition);
		}
		return .None;
	}

	// `property` must live in the project's string pool (use StringPool.Intern).
	public EditError Set(WidgetNodeData instance, List<StableId> path, StringView property, Value value)
	{
		let error = ValidatePath(instance, path);
		if (error != .None)
			return error;
		mStack.Execute(new SetOverrideCommand(mSession, instance, path, property, value));
		return .None;
	}

	public EditError Clear(WidgetNodeData instance, OverrideEntry entry)
	{
		if (!instance.mOverrides.Contains(entry))
			return .NotFound;
		mStack.Execute(new ClearOverrideCommand(mSession, instance, entry));
		return .None;
	}
}
