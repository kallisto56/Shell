namespace Shell.Blueprints;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;

class GraphNode
{
	public StableId mId;
	public NodeKind mKind;
	public String mTypeName = new .() ~ delete _;       // library / operator id, empty otherwise
	public List<Pin> mPins = new .() ~ DeleteContainerAndItems!(_);
	public List<NodeProperty> mProperties = new .() ~ delete _;
	public float mX;                                    // editor position (saved so layouts survive version control diffs)
	public float mY;
	public String mComment = new .() ~ delete _;

	public Pin FindPin(StableId id)
	{
		for (let pin in mPins)
		{
			if (pin.mId == id)
				return pin;
		}
		return null;
	}
}
