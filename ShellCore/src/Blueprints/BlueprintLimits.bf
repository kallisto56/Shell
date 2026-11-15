namespace Shell.Blueprints;

using System;

// Execution safety limits. Exceeding one aborts the current execution chain, reports a diagnostic and raises the
// debugger's error hook; it never hangs the shell.
static class BlueprintLimits
{
	public const int cMaxCallDepth = 32;            // nested synchronous function calls between Blueprints
	public const int cMaxNodesPerExecution = 10000; // nodes executed by one event run-to-completion
	public const int cMaxLoopIterations = 1000;
	public const int cMaxQueuedEvents = 4096;
}
