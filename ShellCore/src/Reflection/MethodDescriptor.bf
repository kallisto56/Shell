namespace Shell.Reflection;

using System;
using System.Collections;
using Shell.Core;

class MethodDescriptor
{
	public StringView mName;
	public StringView mDescription;
	public List<ParameterDescriptor> mParameters = new .() ~ DeleteContainerAndItems!(_);
	public ValueKind mReturnKind = .None;
	public bool bPure;              // no side effects (can be used as a data node in Blueprints)
	public int mIndex = -1;

	public this(StringView name)
	{
		mName = name;
	}

	public MethodDescriptor Param(StringView name, ValueKind kind)
	{
		mParameters.Add(new ParameterDescriptor(name, kind));
		return this;
	}

	public MethodDescriptor Returns(ValueKind kind)
	{
		mReturnKind = kind;
		return this;
	}
}
