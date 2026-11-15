namespace Shell.Reflection;

using System;
using Shell.Core;

// Anything that exposes typed properties: Widgets, Elements, Blueprint instances.
interface IPropertyHost
{
	TypeDescriptor GetDescriptor();
	Value GetProperty(PropertyDescriptor property);
	Result<void, PropertyError> SetProperty(PropertyDescriptor property, Value value);
	// Observable for dependency tracking (bindings subscribe here). Null if the property is not observable.
	IObservable GetObservable(PropertyDescriptor property);
}
