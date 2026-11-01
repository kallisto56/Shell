namespace Shell.Format;

using System;
using System.Collections;
using Shell.Core;
using Shell.Serialization;

// Builds a DocumentNode. Optional values equal to their default are omitted, which keeps files small and diffs local;
// required values are always written.
class NodeWriter
{
	public DocumentNode mNode;
	public SerializationContext mContext;

	public this(DocumentNode node, SerializationContext context)
	{
		mNode = node;
		mContext = context;
	}

	public void Val(StringView name, Value value)
	{
		let field = new DocumentField();
		field.mName.Set(name);
		field.mValue = value;
		mNode.mFields.Add(field);
	}

	public void Str(StringView name, StringView text) => Val(name, Value.FromString(text));
	public void StrIf(StringView name, StringView text) { if (!text.IsEmpty) Str(name, text); }
	public void Bool(StringView name, bool value, bool defaultValue = false) { if (value != defaultValue) Val(name, Value.FromBool(value)); }
	public void BoolAlways(StringView name, bool value) => Val(name, Value.FromBool(value));
	public void Int(StringView name, int64 value, int64 defaultValue = 0) { if (value != defaultValue) Val(name, Value.FromInt(value)); }
	public void Float(StringView name, double value, double defaultValue = 0) { if (value != defaultValue) Val(name, Value.FromFloat(value)); }
	public void FloatAlways(StringView name, double value) => Val(name, Value.FromFloat(value));
	public void Id(StringView name, StableId id) { if (id.mIsValid) Val(name, Value.FromId(id)); }
	public void IdAlways(StringView name, StableId id) => Val(name, Value.FromId(id));
	public void Flags(StringView name, uint32 value) { if (value != 0) Val(name, Value.FromInt((int64)value)); }

	// Required enum: always written.
	public void Enum<T>(StringView name, T value) where T : enum
	{
		let text = scope String();
		EnumCodec.Name(value, text);
		Val(name, Value.FromEnum(mContext.mDocument.mStrings.Intern(text)));
	}

	// Optional enum: omitted when equal to its default.
	public void EnumIf<T>(StringView name, T value, T defaultValue) where T : enum
	{
		if (value != defaultValue)
			Enum(name, value);
	}

	public DocumentGroup Group(StringView name)
	{
		let existing = mNode.FindGroup(name);
		if (existing != null)
			return existing;
		let group = new DocumentGroup();
		group.mName.Set(name);
		mNode.mGroups.Add(group);
		return group;
	}

	// New child node inside a group. Wrap it with `scope NodeWriter(node, context)` to fill it.
	static public DocumentNode AddNode(DocumentGroup group, StringView type, StableId id)
	{
		let node = new DocumentNode();
		node.mType.Set(type);
		node.mId = id;
		group.mNodes.Add(node);
		return node;
	}
}
