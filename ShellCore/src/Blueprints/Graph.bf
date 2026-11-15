namespace Shell.Blueprints;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;

class Graph
{
	public StableId mId;
	public String mName = new .() ~ delete _;
	public GraphKind mKind;
	public StableId mSignature;         // FunctionSignature id for Function graphs
	public List<GraphNode> mNodes = new .() ~ DeleteContainerAndItems!(_);
	public List<GraphLink> mLinks = new .() ~ DeleteContainerAndItems!(_);
	public List<BlueprintVariable> mLocals = new .() ~ DeleteContainerAndItems!(_);

	public GraphNode FindNode(StableId id)
	{
		for (let node in mNodes)
		{
			if (node.mId == id)
				return node;
		}
		return null;
	}
}
