namespace Shell.Binding;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;

// The saved form of a binding: which property of the owning object is driven by which source, through which converters.
class BindingDescriptor
{
	public StableId mId;
	public StringView mTargetProperty;
	public BindingSource mSource;
	public List<ConverterStep> mConverters = new .() ~ delete _;
	public BindingMode mMode = .OneWay;
	public Value mFallback;                 // used while the source is missing or produces an error
}
