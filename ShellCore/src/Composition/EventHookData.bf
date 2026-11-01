namespace Shell.Composition;

using System;
using Shell.Core;

// Connects a widget event to a Blueprint event node (custom event name) of an attached Blueprint.
struct EventHookData
{
	public StableId mId;
	public StringView mWidgetEvent;
	public StableId mBlueprint;             // BlueprintAsset id attached to the widget
	public StringView mBlueprintEvent;
}
