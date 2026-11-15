namespace Shell.Widgets;

using System;

// State flags that style rules and animation state machines can test. Custom named states live in the widget's
// property list (bool State properties) and are addressed by name in style conditions.
enum WidgetStateFlags : uint16
{
	case None = 0;
	case Hovered = 1;
	case Pressed = 2;
	case Focused = 4;
	case Disabled = 8;
	case Checked = 16;
	case Selected = 32;
	case KeyboardFocused = 64;      // focus reached by keyboard navigation (focus ring visible)
}
