namespace Shell.Styling;

using System;
using Shell.Widgets;

// When a rule applies. Required flags must all be set, forbidden flags must all be clear. Custom states are bool State
// properties of the widget type, addressed by name.
struct StyleCondition
{
	public WidgetStateFlags mRequired;
	public WidgetStateFlags mForbidden;
	public StringView mNamedState;          // empty = unused
	public bool mNamedStateValue;
}
