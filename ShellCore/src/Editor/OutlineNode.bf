namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;

// One row of the composition hierarchy. The path is what overrides use to address the object from the edited definition:
// [id] for the definition's own objects, [instance id, ..., inner id] for objects inside nested UserWidget instances.
class OutlineNode
{
	public List<StableId> mPath = new .() ~ delete _;
	public OutlineKind mKind;
	public String mName = new .() ~ delete _;
	public String mTypeName = new .() ~ delete _;
	public StableId mDefinition;            // instances: the definition they instantiate
	public StableId mLayer;                 // elements: assigned layer (none = inherited)
	public OutlineNode mParent;
	public List<OutlineNode> mChildren = new .() ~ DeleteContainerAndItems!(_);
	public bool bEssential;
	public bool bReadOnly;                  // inside a nested instance: edit it by opening its definition, or use an override
	public bool bExposed;                   // some exposed member of the edited definition points here
	public int mOverrideCount;              // instances: number of saved overrides

	public StableId mId => (mPath.Count > 0) ? mPath[mPath.Count - 1] : .sNone;
}
