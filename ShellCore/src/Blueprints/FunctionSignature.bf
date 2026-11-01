namespace Shell.Blueprints;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;

class FunctionSignature
{
	public StableId mId;
	public String mName = new .() ~ delete _;
	public List<ParameterDescriptor> mInputs = new .() ~ DeleteContainerAndItems!(_);
	public List<ParameterDescriptor> mOutputs = new .() ~ DeleteContainerAndItems!(_);
}
