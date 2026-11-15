namespace Shell.Reflection;

using System;
using Shell.Core;

interface IMethodHost
{
	Result<Value, CallError> Invoke(MethodDescriptor method, Span<Value> arguments);
}
