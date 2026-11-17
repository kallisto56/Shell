namespace Shell.Editor;

using System;
using Shell.Core;

// One element as it appears inside a layer row of the layer editor.
class LayerEntry
{
	public StableId mElement;
	public String mName = new .() ~ delete _;
	public int mDepth;              // depth in the ownership tree (indentation)
	public bool bInherited;         // the layer comes from an ancestor, not from the element itself
	public bool bEssential;
}
