namespace Shell.Composition;

using System;
using System.Collections;
using Shell.Core;

// Per-instance override of a property of something inside a UserWidget definition. The target is addressed by the chain
// of stable ids from the instance down to the object, so overrides survive renames, reordering and nesting; a target that
// no longer exists keeps the entry (orphaned) and raises a diagnostic instead of silently dropping the user's work.
class OverrideEntry
{
	public List<StableId> mPath = new .() ~ delete _;   // [nested instance ..., target object]
	public StringView mProperty;
	public Value mValue;
}
