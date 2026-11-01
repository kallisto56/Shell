namespace Shell.Blueprints;

using System;
using Shell.Core;

// The scheduler / registry of live Blueprint instances.
//   * Events are queued and executed FIFO, each to completion, in the Blueprints phase (no interleaving).
//   * Calls to public functions are synchronous and bounded by BlueprintLimits.cMaxCallDepth.
//   * An instance may not be re-entered by an event while one of its executions is running (events are queued);
//     direct recursive function calls are allowed up to the depth limit.
interface IBlueprintHost
{
	IBlueprintInstance Resolve(BlueprintRef reference, IBlueprintInstance caller);
	CallResult Call(BlueprintRef reference, IBlueprintInstance caller, StringView function, Span<Value> arguments);
}
