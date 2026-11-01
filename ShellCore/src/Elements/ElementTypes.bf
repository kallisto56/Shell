namespace Shell.Elements;

using System;
using Shell.Core;
using Shell.Reflection;

// Property descriptors shared by all elements. Per-kind types (Shape, Text, Image ...) derive from "Element".
static class ElementTypes
{
	static public TypeDescriptor sElement;
	static public PropertyDescriptor sVisible;
	static public PropertyDescriptor sOpacity;
	static public PropertyDescriptor sPosition;
	static public PropertyDescriptor sSize;
	static public PropertyDescriptor sScale;
	static public PropertyDescriptor sRotation;
	static public PropertyDescriptor sPivot;
	static public PropertyDescriptor sClipToBounds;

	static public bool Register(RuntimeContext context)
	{
		if (sElement == null)
			Create();
		return context.mTypes.Register(sElement, context.mDiagnostics, false);
	}

	static void Create()
	{
		sElement = new TypeDescriptor("Element", .Element);

		sVisible = sElement.AddProperty(new PropertyDescriptor("Visible", .Bool) { mDefault = Value.FromBool(true), mInvalidates = .Layout | .Visual, mFlags = .Serialized | .Bindable | .Animatable });
		sOpacity = sElement.AddProperty(new PropertyDescriptor("Opacity", .Float) { mDefault = Value.FromFloat(1), mInvalidates = .Visual, mFlags = .Serialized | .Bindable | .Animatable | .Styleable });
		sPosition = sElement.AddProperty(new PropertyDescriptor("Position", .Vector2) { mInvalidates = .Layout, mFlags = .Serialized | .Bindable | .Animatable });
		sSize = sElement.AddProperty(new PropertyDescriptor("Size", .Vector2) { mInvalidates = .Layout, mFlags = .Serialized | .Bindable | .Animatable });
		sScale = sElement.AddProperty(new PropertyDescriptor("Scale", .Vector2) { mDefault = Value.FromVector2(1, 1), mInvalidates = .Visual, mFlags = .Serialized | .Bindable | .Animatable });
		sRotation = sElement.AddProperty(new PropertyDescriptor("Rotation", .Float) { mInvalidates = .Visual, mDescription = "Radians, clockwise.", mFlags = .Serialized | .Bindable | .Animatable });
		sPivot = sElement.AddProperty(new PropertyDescriptor("Pivot", .Vector2) { mDefault = Value.FromVector2(0.5f, 0.5f), mInvalidates = .Visual, mDescription = "Normalized pivot of scale and rotation.", mFlags = .Serialized | .Bindable });
		sClipToBounds = sElement.AddProperty(new PropertyDescriptor("ClipToBounds", .Bool) { mInvalidates = .Visual });

	}
}
