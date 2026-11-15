namespace Shell.Binding;

using System;

enum BindingMode
{
	case OneWay;        // source -> target
	case TwoWay;        // source <-> target (target must be writable, source must accept writes)
	case OneTime;       // evaluated once on activation
}
