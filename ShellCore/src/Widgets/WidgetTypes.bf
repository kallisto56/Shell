namespace Shell.Widgets;

using System;
using Shell.Core;
using Shell.Reflection;

// Descriptor of the base "Widget" type: the public surface every widget has. Derived widgets (Button, TextBox ...)
// add their own typed properties, methods and events on top; nothing here forces identical properties on all widgets.
//
// How the public state reaches the other systems (all through these descriptors):
//   * Element bindings: BindingSource OwnerProperty / ParentProperty / WidgetProperty -> IPropertyHost.GetObservable
//   * Blueprints:       Get/Set property nodes (IPropertyHost), Call method nodes (IMethodHost), event nodes (IEventSource)
//   * Style / animation: WidgetStateFlags derived from the State properties below
//   * Editor:           inspector lists the descriptors, grouped by PropertyKind
static class WidgetTypes
{
	static public TypeDescriptor sWidget;

	// Writable properties
	static public PropertyDescriptor sName;
	static public PropertyDescriptor sEnabled;
	static public PropertyDescriptor sVisible;
	static public PropertyDescriptor sFocusable;
	static public PropertyDescriptor sTabIndex;
	static public PropertyDescriptor sHitTestVisible;
	static public PropertyDescriptor sFocusScope;
	static public PropertyDescriptor sCursor;
	static public PropertyDescriptor sBounds;

	// Read-only state (changed only by the widget runtime)
	static public PropertyDescriptor sHovered;
	static public PropertyDescriptor sPressed;
	static public PropertyDescriptor sFocused;
	static public PropertyDescriptor sKeyboardFocused;

	// Computed
	static public PropertyDescriptor sIsEffectivelyEnabled;    // Enabled and all ancestors enabled

	// Events
	static public EventDescriptor sPointerEntered;
	static public EventDescriptor sPointerExited;
	static public EventDescriptor sFocusGained;
	static public EventDescriptor sFocusLost;

	// Methods
	static public MethodDescriptor sFocus;
	static public MethodDescriptor sBlur;

	static public bool Register(RuntimeContext context)
	{
		if (sWidget == null)
			Create();
		return context.mTypes.Register(sWidget, context.mDiagnostics, false);
	}

	static void Create()
	{
		sWidget = new TypeDescriptor("Widget", .Widget);

		sName = sWidget.AddProperty(new PropertyDescriptor("Name", .String) { mInvalidates = .None });
		sEnabled = sWidget.AddProperty(new PropertyDescriptor("Enabled", .Bool) { mDefault = Value.FromBool(true), mInvalidates = .Style | .Visual });
		sVisible = sWidget.AddProperty(new PropertyDescriptor("Visible", .Bool) { mDefault = Value.FromBool(true), mInvalidates = .Layout | .Visual });
		sFocusable = sWidget.AddProperty(new PropertyDescriptor("Focusable", .Bool) { mInvalidates = .None });
		sTabIndex = sWidget.AddProperty(new PropertyDescriptor("TabIndex", .Int) { mInvalidates = .None, mDescription = "Tab order: ascending, ties in tree order. Negative = skipped by Tab." });
		sHitTestVisible = sWidget.AddProperty(new PropertyDescriptor("HitTestVisible", .Bool) { mDefault = Value.FromBool(true), mInvalidates = .None });
		sFocusScope = sWidget.AddProperty(new PropertyDescriptor("FocusScope", .Bool) { mInvalidates = .None, mDescription = "Tab navigation cycles inside the nearest scope (dialogs, menus)." });
		sCursor = sWidget.AddProperty(new PropertyDescriptor("Cursor", .Enum) { mDefault = Value.FromEnum("Default"), mEnumType = "CursorKind", mInvalidates = .None });
		sBounds = sWidget.AddProperty(new PropertyDescriptor("Bounds", .Rect) { mInvalidates = .Layout, mFlags = .Serialized | .Bindable | .Animatable });

		sHovered = sWidget.AddProperty(new PropertyDescriptor("Hovered", .Bool) { mKind = .State, mFlags = .Bindable, mInvalidates = .Style | .Visual });
		sPressed = sWidget.AddProperty(new PropertyDescriptor("Pressed", .Bool) { mKind = .State, mFlags = .Bindable, mInvalidates = .Style | .Visual });
		sFocused = sWidget.AddProperty(new PropertyDescriptor("Focused", .Bool) { mKind = .State, mFlags = .Bindable, mInvalidates = .Style | .Visual });
		sKeyboardFocused = sWidget.AddProperty(new PropertyDescriptor("KeyboardFocused", .Bool) { mKind = .State, mFlags = .Bindable, mInvalidates = .Style | .Visual });

		sIsEffectivelyEnabled = sWidget.AddProperty(new PropertyDescriptor("IsEffectivelyEnabled", .Bool) { mKind = .Computed, mFlags = .Bindable, mInvalidates = .Style | .Visual });

		sPointerEntered = sWidget.AddEvent(new EventDescriptor("PointerEntered"));
		sPointerExited = sWidget.AddEvent(new EventDescriptor("PointerExited"));
		sFocusGained = sWidget.AddEvent(new EventDescriptor("FocusGained"));
		sFocusLost = sWidget.AddEvent(new EventDescriptor("FocusLost"));

		sFocus = sWidget.AddMethod(new MethodDescriptor("Focus").Returns(.Bool));
		sBlur = sWidget.AddMethod(new MethodDescriptor("Blur"));

	}
}
