namespace Shell.Format;

using System;
using System.Collections;
using Shell.Core;
using Shell.Serialization;

// Typed access to the fields of a DocumentNode with diagnostics. Missing optional fields yield defaults; wrong
// types, invalid enum names and unknown fields are reported (never ignored silently). Strings are interned in the target pool.
class NodeReader
{
	public DocumentNode mNode;
	public SerializationContext mContext;
	List<bool> mUsed = new .() ~ delete _;

	public this(DocumentNode node, SerializationContext context)
	{
		mNode = node;
		mContext = context;
		for (int i < node.mFields.Count)
			mUsed.Add(false);
	}

	public StableId mId => mNode.mId;

	void Report(StringView code, StringView message)
	{
		mContext.mSink.Error(code, scope $"{mNode.mType}: {message}", mNode.mId);
	}

	DocumentField Find(StringView name)
	{
		for (int i < mNode.mFields.Count)
		{
			if (mNode.mFields[i].mName == name)
			{
				mUsed[i] = true;
				return mNode.mFields[i];
			}
		}
		return null;
	}

	public bool Has(StringView name)
	{
		for (let field in mNode.mFields)
		{
			if (field.mName == name)
				return true;
		}
		return false;
	}

	DocumentField FindTyped(StringView name, ValueKind kind, bool required)
	{
		let field = Find(name);
		if (field == null)
		{
			if (required)
				Report("SER0201", scope $"required field '{name}' is missing.");
			return null;
		}
		if (field.mValue.mKind != kind)
		{
			Report("SER0202", scope $"field '{name}' has type {ValueCodec.KindName(field.mValue.mKind)}, expected {ValueCodec.KindName(kind)}.");
			return null;
		}
		return field;
	}

	public StringView Str(StringView name, bool required = false)
	{
		let field = FindTyped(name, .String, required);
		return (field != null) ? mContext.mStrings.Intern(field.mValue.mString) : default;
	}

	public void StrInto(StringView name, String output, bool required = false)
	{
		let field = FindTyped(name, .String, required);
		if (field != null)
			output.Set(field.mValue.mString);
	}

	public bool Bool(StringView name, bool defaultValue = false)
	{
		let field = FindTyped(name, .Bool, false);
		return (field != null) ? (field.mValue.mInt != 0) : defaultValue;
	}

	public int64 Int(StringView name, int64 defaultValue = 0)
	{
		let field = FindTyped(name, .Int, false);
		return (field != null) ? field.mValue.mInt : defaultValue;
	}

	public double Float(StringView name, double defaultValue = 0)
	{
		let field = Find(name);
		if (field == null)
			return defaultValue;
		if (field.mValue.mKind == .Float) return field.mValue.mFloat;
		if (field.mValue.mKind == .Int) return (double)field.mValue.mInt;
		Report("SER0202", scope $"field '{name}' has type {ValueCodec.KindName(field.mValue.mKind)}, expected float.");
		return defaultValue;
	}

	public StableId Id(StringView name, bool required = false)
	{
		let field = FindTyped(name, .Id, required);
		return (field != null) ? field.mValue.AsId() : StableId.sNone;
	}

	public uint32 Flags(StringView name)
	{
		return (uint32)Int(name, 0);
	}

	public T Enum<T>(StringView name, T defaultValue) where T : enum
	{
		let field = Find(name);
		if (field == null)
			return defaultValue;
		if (field.mValue.mKind != .Enum)
		{
			Report("SER0202", scope $"field '{name}' has type {ValueCodec.KindName(field.mValue.mKind)}, expected enum.");
			return defaultValue;
		}
		if (EnumCodec.Parse<T>(field.mValue.mString) case .Ok(let value))
			return value;
		Report("SER0203", scope $"'{field.mValue.mString}' is not a valid value for '{name}'.");
		return defaultValue;
	}

	// Any kind of value (properties, constants, defaults). Strings are re-interned into the target pool.
	public Value Val(StringView name)
	{
		let field = Find(name);
		return (field != null) ? Reintern(field.mValue) : Value.sNone;
	}

	public Value Reintern(Value value)
	{
		var result = value;
		if (value.mKind == .String || value.mKind == .Enum)
			result.mString = mContext.mStrings.Intern(value.mString);
		return result;
	}

	// Fields whose name starts with `prefix` (e.g. "prop."), in file order. Callback style avoided: returns the list.
	public void CollectPrefixed(StringView prefix, List<(StringView name, Value value)> output)
	{
		for (int i < mNode.mFields.Count)
		{
			let field = mNode.mFields[i];
			if (field.mName.StartsWith(prefix))
			{
				mUsed[i] = true;
				output.Add((mContext.mStrings.Intern(field.mName.Substring(prefix.Length)), Reintern(field.mValue)));
			}
		}
	}

	public DocumentGroup Group(StringView name)
	{
		return mNode.FindGroup(name);
	}

	// Call after reading a node: fields nobody asked for are reported as warnings (files from a newer minor version).
	public void ReportUnknown()
	{
		for (int i < mNode.mFields.Count)
		{
			if (!mUsed[i])
				mContext.mSink.Warning("SER0210", scope $"{mNode.mType}: unknown field '{mNode.mFields[i].mName}' was ignored.", mNode.mId);
		}
	}
}
