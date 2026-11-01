namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;

// An event captured for later processing (by the Blueprint host). Argument strings are retained in the string pool, so the
// values stay valid even if the property they came from changes before the event is processed.
class QueuedEvent
{
	public Handle mSource;
	public EventDescriptor mEvent;
	public List<Value> mArguments = new .() ~ delete _;
	StringPool mStrings;

	public this(StringPool strings)
	{
		mStrings = strings;
	}

	public ~this()
	{
		for (let value in mArguments)
		{
			if (value.mKind == .String || value.mKind == .Enum)
				mStrings.Release(value.mString);
		}
	}

	public void AddArgument(Value value)
	{
		if (value.mKind == .String || value.mKind == .Enum)
			mStrings.Retain(value.mString);
		mArguments.Add(value);
	}
}
