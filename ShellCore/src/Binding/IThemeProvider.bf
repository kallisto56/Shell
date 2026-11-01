namespace Shell.Binding;

using System;
using Shell.Core;
using Shell.Reflection;

// Supplies design tokens of the active theme to bindings (BindingSourceKind.StyleToken).
interface IThemeProvider
{
	Result<Value> GetToken(StringView name);
	IObservable ObserveToken(StringView name);
}
