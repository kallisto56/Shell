namespace Shell.Binding;

using System;
using Shell.Core;
using Shell.Reflection;

// Looks up binding sources inside a context. Missing sources are never silent: the resolver reports a diagnostic
// (with the binding's owner as source) and the binding falls back to its fallback value.
interface IBindingResolver
{
	IObservable Observe(BindingSource source, RuntimeObject context);
	// The object that owns the observable returned by the most recent Observe() call (null for globals, time, tokens).
	// Lets the binding system detach bindings before their source object is destroyed.
	RuntimeObject GetLastSourceObject();
	Result<Value> Read(BindingSource source, RuntimeObject context);
	Result<void> Write(BindingSource source, RuntimeObject context, Value value);
}
