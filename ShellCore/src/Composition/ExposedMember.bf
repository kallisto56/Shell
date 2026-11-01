namespace Shell.Composition;

using System;
using Shell.Core;

// One entry of a UserWidget's public interface, forwarded to an inner member. The public name is what the instance
// shows; renaming or re-targeting the inner member keeps instances valid as long as the public name and kind stay.
class ExposedMember
{
	public StableId mId;
	public String mPublicName = new .() ~ delete _;
	public ExposedKind mKind;
	public ValueKind mValueKind;
	public StableId mInnerTarget;           // widget / element / blueprint attachment inside the definition
	public StringView mInnerMember;         // property, variable, method or event name on the target
	public bool bWritable;
}
