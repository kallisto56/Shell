namespace Shell.Blueprints;

using System;
using Shell.Core;

// How one Blueprint names another. References are by id, never by display name, and resolve to a live instance at call
// time through IBlueprintHost; an unresolved reference is a reported failure with a defined result (CallStatus).
struct BlueprintRef
{
	public BlueprintRefKind mKind;
	public StableId mTarget;
}
