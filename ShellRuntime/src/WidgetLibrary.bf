namespace Shell.Runtime;

using System;
using Shell.Core;
using Shell.Widgets;
using Shell.Elements;

// Registers the built-in widget and element types in a context. The descriptors are process-wide singletons (created on first use),
// so any number of contexts - editor preview, simulation, real shell - share them.
static class WidgetLibrary
{
	// Widget classes that can be created from saved type names. UserWidget instances are created by the UserWidgetHost.
	static public void RegisterFactory(WidgetFactory factory)
	{
		factory.Register<ContainerWidget>("Container");
		factory.Register<Button>("Button");
		factory.Register<TextBox>("TextBox");
	}

	static public bool RegisterTypes(RuntimeContext context)
	{
		bool bOk = true;
		if (context.mTypes.Find("Widget") == null) bOk &= WidgetTypes.Register(context);
		if (context.mTypes.Find("Element") == null) bOk &= ElementTypes.Register(context);
		if (context.mTypes.Find("Container") == null) bOk &= ContainerWidget.Register(context);
		if (context.mTypes.Find("Button") == null) bOk &= Button.Register(context);
		if (context.mTypes.Find("TextBox") == null) bOk &= TextBox.Register(context);
		if (context.mTypes.Find("UserWidget") == null) bOk &= UserWidget.Register(context);
		return bOk;
	}
}
