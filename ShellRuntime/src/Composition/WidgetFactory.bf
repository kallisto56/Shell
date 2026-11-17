namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Widgets;

// Creates widgets by the type name stored in the saved format (WidgetNodeData.mTypeName).
class WidgetFactory
{
	Dictionary<String, IWidgetCreator> mCreators = new .() ~ delete _;

	public ~this()
	{
		for (let entry in mCreators)
		{
			delete entry.key;
			delete entry.value;
		}
	}

	public void Register<T>(StringView typeName) where T : Widget, new
	{
		let key = scope String(typeName);
		if (mCreators.GetAndRemove(key) case .Ok(let old))
		{
			delete old.key;
			delete old.value;
		}
		mCreators[new String(typeName)] = new WidgetCreator<T>();
	}

	// Null when the type name is unknown.
	public Widget Create(StringView typeName)
	{
		let key = scope String(typeName);
		if (mCreators.TryGetValue(key, let creator))
			return creator.Create();
		return null;
	}
}
