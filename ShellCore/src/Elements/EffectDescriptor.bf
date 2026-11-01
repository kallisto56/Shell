namespace Shell.Elements;

using System;
using System.Collections;
using Shell.Core;

class EffectDescriptor
{
	public StableId mId;
	public EffectKind mKind;
	public StringView mCustomName;
	public bool bEnabled = true;
	public List<Value> mParameters = new .() ~ delete _;    // meaning depends on the kind (blur radius, shadow offset/color ...)
}
