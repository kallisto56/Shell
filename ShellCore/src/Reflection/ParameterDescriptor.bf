namespace Shell.Reflection;

using System;
using Shell.Core;

class ParameterDescriptor
{
	public StringView mName;
	public ValueKind mKind;
	public Value mDefault;      // used when a caller omits the argument

	public this(StringView name, ValueKind kind)
	{
		mName = name;
		mKind = kind;
	}
}
