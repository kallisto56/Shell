namespace Shell.Runtime;

using System;
using Shell.Input;

class InputEntry
{
	public InputEntryKind mKind;
	public PointerEvent mPointer;
	public KeyEvent mKey;
	public String mText = new .() ~ delete _;
}
