namespace Shell.Format;

using System;
using System.Collections;
using Shell.Core;
using Shell.Composition;

// Property assignments are stored as fields named "prop.<Name>" so they stay one line each and diff cleanly.
static class PropertyValues
{
	static public void Write(List<PropertyValueData> properties, NodeWriter writer)
	{
		for (let property in properties)
			writer.Val(scope $"prop.{property.mName}", property.mValue);
	}

	static public void Read(NodeReader reader, List<PropertyValueData> output)
	{
		let items = scope List<(StringView name, Value value)>();
		reader.CollectPrefixed("prop.", items);
		for (let item in items)
		{
			PropertyValueData data = default;
			data.mName = item.name;
			data.mValue = item.value;
			output.Add(data);
		}
	}
}
