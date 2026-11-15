namespace Shell.Runtime;

using System;
using Shell.Core;
using Shell.Reflection;

// Declarative helper for widget types. A widget declares its public surface once, in a static type description:
//
//   let b = new WidgetTypeBuilder("Slider", WidgetTypes.sWidget);
//   sValue   = b.AddValue("Value", .Float, Value.FromFloat(0), .Visual);          // writable, serialized, bindable
//   sFraction = b.AddComputed("Fraction", .Float);                                // derived, read-only
//   sDragging = b.AddState("Dragging", .Bool);                                    // read-only from outside
//   sChanged = b.AddEvent("ValueChanged").Param("Value", .Float);
//   sReset   = b.AddMethod("Reset");
//   sType = b.mType;  (then register it: context.mTypes.Register(sType, sink, false))
//
// The widget class implements the behavior: it writes State properties with SetState(), overrides GetProperty for Computed ones and
// OnInvokeMethod for methods; the editor, bindings, Blueprints and serialization use the descriptors only.
class WidgetTypeBuilder
{
	public TypeDescriptor mType;

	public this(StringView name, TypeDescriptor baseType)
	{
		mType = new TypeDescriptor(name, .Widget, baseType);
	}

	public PropertyDescriptor AddValue(StringView name, ValueKind kind, Value defaultValue = default, Invalidation invalidates = .Visual,
		PropertyFlags flags = .Serialized | .Bindable, StringView enumType = default)
	{
		return mType.AddProperty(new PropertyDescriptor(name, kind) { mKind = .Value, mDefault = defaultValue, mInvalidates = invalidates, mFlags = flags, mEnumType = enumType });
	}

	public PropertyDescriptor AddState(StringView name, ValueKind kind, Value defaultValue = default, Invalidation invalidates = .Style | .Visual)
	{
		return mType.AddProperty(new PropertyDescriptor(name, kind) { mKind = .State, mDefault = defaultValue, mInvalidates = invalidates, mFlags = .Bindable });
	}

	public PropertyDescriptor AddComputed(StringView name, ValueKind kind)
	{
		return mType.AddProperty(new PropertyDescriptor(name, kind) { mKind = .Computed, mInvalidates = .Visual, mFlags = .Bindable });
	}

	public EventDescriptor AddEvent(StringView name)
	{
		return mType.AddEvent(new EventDescriptor(name));
	}

	public MethodDescriptor AddMethod(StringView name)
	{
		return mType.AddMethod(new MethodDescriptor(name));
	}
}
