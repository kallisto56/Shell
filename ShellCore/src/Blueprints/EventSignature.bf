namespace Shell.Blueprints;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;

class EventSignature
{
	public StableId mId;
	public String mName = new .() ~ delete _;
	public List<ParameterDescriptor> mParameters = new .() ~ DeleteContainerAndItems!(_);
}
