namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Widgets;
using Shell.Input;
using Shell.Text;
using Shell.Platform;

// Plain grouping widget: no behavior of its own. Transparent to the pointer unless BlocksInput is set (a panel that must swallow
// clicks). Positions its children only through their Bounds; layout engines arrive with the layout stage.
class ContainerWidget : Widget
{
	static public TypeDescriptor sType;
	static public PropertyDescriptor sBlocksInput;

	static public bool Register(RuntimeContext context)
	{
		if (sType == null)
		{
			let b = new WidgetTypeBuilder("Container", WidgetTypes.sWidget);
			sBlocksInput = b.AddValue("BlocksInput", .Bool, Value.FromBool(false), .None);
			sType = b.mType;
			delete b;
		}
		return context.mTypes.Register(sType, context.mDiagnostics, false);
	}

	public override TypeDescriptor GetDescriptor() => sType;

	public override bool mBlocksPointer => mProperties.Get(sBlocksInput).AsBool() && base.mBlocksPointer;
}
