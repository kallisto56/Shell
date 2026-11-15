namespace Shell.Binding;

using System;

enum BindingSourceKind
{
	case Constant;          // literal value
	case WidgetProperty;    // property of a specific Widget/Element (mTarget = its StableId)
	case OwnerProperty;     // property of the Widget that owns the bound Element (the usual case inside a Widget skin)
	case ParentProperty;    // property of the nearest ancestor Widget that has it
	case GlobalVariable;    // GlobalVariableStore entry (mMember = name)
	case BlueprintVariable; // public variable of a Blueprint instance (mTarget = instance, mMember = name)
	case StyleToken;        // design token of the active theme
	case AnimationInput;    // input of an animation state machine (mTarget = machine)
	case TimeBuiltin;       // Time, UnscaledTime, DeltaTime, UnscaledDeltaTime
}
