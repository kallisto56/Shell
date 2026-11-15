namespace Shell.Blueprints;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;

// Global state shared by unrelated Blueprints, Widgets and bindings (for example "HighAlertMode"). Typed, with initial
// values, observable. Changes notify observers synchronously (marking bindings and event nodes dirty); the work they
// trigger runs later in the proper phase.
class GlobalVariableStore
{
	class Entry
	{
		public GlobalVariableDefinition mDefinition ~ delete _;
		public Value mValue;
		public ObservableValue mObservable = new .() ~ delete _;
	}

	Dictionary<String, Entry> mByName = new .() ~ delete _;
	List<Entry> mOrdered = new .() ~ DeleteContainerAndItems!(_);

	public ~this()
	{
		for (let key in mByName.Keys)
			delete key;
	}

	// Takes ownership of the definition. Fails on duplicate names.
	public bool Define(GlobalVariableDefinition definition, DiagnosticSink sink)
	{
		let key = scope String(definition.mName);
		if (mByName.ContainsKey(key))
		{
			sink.Error("GLB0001", scope $"Global variable '{definition.mName}' is already defined.", definition.mId);
			delete definition;
			return false;
		}

		let entry = new Entry();
		entry.mDefinition = definition;
		entry.mValue = definition.mInitial;
		mByName[new String(definition.mName)] = entry;
		mOrdered.Add(entry);
		return true;
	}

	Entry Find(StringView name)
	{
		let key = scope String(name);
		if (mByName.TryGetValue(key, let entry))
			return entry;
		return null;
	}

	public Result<Value> Get(StringView name)
	{
		let entry = Find(name);
		if (entry == null)
			return .Err;
		return .Ok(entry.mValue);
	}

	// Type-checked. Returns Ok(true) if the value changed (observers were notified).
	public Result<bool> Set(StringView name, Value value, DiagnosticSink sink)
	{
		let entry = Find(name);
		if (entry == null)
		{
			sink.Error("GLB0002", scope $"Unknown global variable '{name}'.");
			return .Err;
		}

		var stored = value;
		if (entry.mDefinition.mKind == .Float && value.mKind == .Int)
			stored = Value.FromFloat((double)value.mInt);
		if (stored.mKind != entry.mDefinition.mKind)
		{
			sink.Error("GLB0003", scope $"Global variable '{name}' has a different type than the assigned value.", entry.mDefinition.mId);
			return .Err;
		}

		if (entry.mValue.Equals(stored))
			return .Ok(false);

		entry.mValue = stored;
		entry.mObservable.NotifyChanged();
		return .Ok(true);
	}

	public IObservable Observe(StringView name)
	{
		let entry = Find(name);
		return (entry != null) ? entry.mObservable : null;
	}

	public void ResetAll()
	{
		for (let entry in mOrdered)
		{
			if (!entry.mValue.Equals(entry.mDefinition.mInitial))
			{
				entry.mValue = entry.mDefinition.mInitial;
				entry.mObservable.NotifyChanged();
			}
		}
	}

	// Definition order (stable, used by the serializer).
	public void GetDefinitions(List<GlobalVariableDefinition> output)
	{
		for (let entry in mOrdered)
			output.Add(entry.mDefinition);
	}
}
