namespace Shell.Reflection;

using System;
using System.Collections;
using Shell.Core;

// Owns all TypeDescriptors of a context. Registration order is the order in which types were added; enumeration for
// serialization sorts by name so output does not depend on registration order.
class TypeRegistry
{
	Dictionary<String, TypeDescriptor> mTypes = new .() ~ delete _;
	List<TypeDescriptor> mOrdered = new .() ~ delete _;
	List<bool> mOwned = new .() ~ delete _;     // false for shared descriptors owned by a library (built-in widget types)

	public ~this()
	{
		for (int i < mOrdered.Count)
		{
			if (mOwned[i])
				delete mOrdered[i];
		}
		for (let key in mTypes.Keys)
			delete key;
	}

	// ownsType = false registers a shared descriptor (a static singleton created once per process and used by every context).
	public bool Register(TypeDescriptor type, DiagnosticSink sink, bool ownsType = true)
	{
		let key = scope String(type.mName);
		if (mTypes.ContainsKey(key))
		{
			sink.Error("REF0003", scope $"Type '{type.mName}' is already registered.");
			return false;
		}
		if (!type.Finish(sink))
			return false;

		mTypes[new String(type.mName)] = type;
		mOrdered.Add(type);
		mOwned.Add(ownsType);
		return true;
	}

	public TypeDescriptor Find(StringView name)
	{
		let key = scope String(name);
		if (mTypes.TryGetValue(key, let type))
			return type;
		return null;
	}

	public void GetSortedTypes(List<TypeDescriptor> output)
	{
		output.AddRange(mOrdered);
		output.Sort(scope (a, b) => a.mName.CompareTo(b.mName));
	}
}
