namespace Shell.Composition;

using System;
using Shell.Core;

struct BlueprintAttachment
{
	public StableId mInstanceId;            // stable id of this attachment (so exposed members can target it)
	public StableId mBlueprint;             // BlueprintAsset id
}
