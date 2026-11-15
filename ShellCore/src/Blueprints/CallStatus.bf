namespace Shell.Blueprints;

using System;

enum CallStatus
{
	case Ok;
	case TargetMissing;     // no live instance for the reference
	case NotPublic;         // member exists but is not part of the public interface
	case SignatureMismatch; // argument count / types do not match the signature
	case DepthExceeded;     // BlueprintLimits.cMaxCallDepth
	case ReentrancyBlocked; // the call would re-enter an execution that forbids it (see ARCHITECTURE.md)
	case Faulted;           // the callee aborted (limit hit, error node)
}
