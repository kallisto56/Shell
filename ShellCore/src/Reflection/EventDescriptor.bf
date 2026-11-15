namespace Shell.Reflection;

using System;
using System.Collections;
using Shell.Core;

class EventDescriptor
{
	public StringView mName;
	public StringView mDescription;
	public List<ParameterDescriptor> mParameters = new .() ~ DeleteContainerAndItems!(_);
	public int mIndex = -1;

	public this(StringView name)
	{
		mName = name;
	}

	public EventDescriptor Param(StringView name, ValueKind kind)
	{
		mParameters.Add(new ParameterDescriptor(name, kind));
		return this;
	}
}
