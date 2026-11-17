namespace Shell.Runtime;

using System;
using Shell.Widgets;

class WidgetCreator<T> : IWidgetCreator where T : Widget, new
{
	public Widget Create() => new T();
}
