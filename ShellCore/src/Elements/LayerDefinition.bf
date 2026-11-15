namespace Shell.Elements;

using System;
using Shell.Core;

// A named render layer of one Widget skin. Layers define draw order independently of the ownership tree: an element
// owned by the Content container can be drawn in the Overlay layer. Layers render in ascending order.
class LayerDefinition
{
	public StableId mId;
	public String mName = new .() ~ delete _;
	public LayerRole mRole;
	public int mOrder;
	public bool bEssential;     // Content cannot be removed or reordered below Underlay, so Widget behavior cannot break
}
