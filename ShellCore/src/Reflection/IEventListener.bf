namespace Shell.Reflection;

using System;
using Shell.Core;

interface IEventListener
{
	void OnEvent(RuntimeObject source, EventDescriptor ev, Span<Value> arguments);
}
