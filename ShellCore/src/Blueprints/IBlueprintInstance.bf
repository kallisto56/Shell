namespace Shell.Blueprints;

using System;
using Shell.Core;
using Shell.Reflection;

// A running Blueprint. Only the public interface is reachable from outside.
interface IBlueprintInstance
{
	BlueprintAsset GetAsset();
	StableId GetInstanceId();
	Result<Value, CallStatus> GetPublicVariable(StringView name);
	Result<void, CallStatus> SetPublicVariable(StringView name, Value value);
	CallResult CallFunction(StringView name, Span<Value> arguments);
	// Raises a public event on this instance (listeners run later, queued).
	void RaiseEvent(StringView name, Span<Value> arguments);
}
