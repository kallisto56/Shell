namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;

// One layer of the layer editor with the elements drawn in it, in draw order.
class LayerRow
{
	public StableId mId;
	public String mName = new .() ~ delete _;
	public LayerRole mRole;
	public int mOrder;
	public bool bEssential;
	public bool bBeforeChildren;    // drawn before the widget's child widgets (order <= 0); the others are drawn after them
	public List<LayerEntry> mEntries = new .() ~ DeleteContainerAndItems!(_);
}
