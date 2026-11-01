namespace Shell.Blueprints;

using System;
using Shell.Core;

// Debug hooks for the editor (breakpoints, stepping, value inspection, error markers). Optional; null in the real shell.
interface IBlueprintDebugger
{
	// Return true to pause before the node runs.
	bool OnNodeExecuting(IBlueprintInstance instance, Graph graph, GraphNode node);
	void OnPinValue(IBlueprintInstance instance, Graph graph, Pin pin, Value value);
	void OnError(IBlueprintInstance instance, Graph graph, GraphNode node, StringView code, StringView message);
}
