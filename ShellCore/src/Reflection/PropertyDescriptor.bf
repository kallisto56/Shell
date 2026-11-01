namespace Shell.Reflection;

using System;
using Shell.Core;

// Typed description of one property of a Widget / Element type. The descriptor is the single source of truth for the
// editor inspector, bindings, Blueprint nodes, serialization and validation.
class PropertyDescriptor
{
	public StringView mName;                // unique inside the type, stable (it is part of the saved format)
	public ValueKind mValueKind;
	public PropertyKind mKind = .Value;
	public PropertyFlags mFlags = .Serialized | .Bindable;
	public Invalidation mInvalidates = .Visual;
	public Value mDefault;
	public StringView mEnumType;            // for ValueKind.Enum
	public StringView mDescription;
	public int mIndex = -1;                 // slot in PropertyStore, assigned by TypeDescriptor.Finish()

	public this(StringView name, ValueKind kind)
	{
		mName = name;
		mValueKind = kind;
	}

	public bool mIsWritable => mKind == .Value;
	public bool mIsSerialized => mKind == .Value && (mFlags & .Serialized) != 0;
}
