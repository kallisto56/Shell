namespace Shell.Blueprints;

using System;
using Shell.Core;

class Pin
{
	public StableId mId;
	public String mName = new .() ~ delete _;
	public PinDirection mDirection;
	public PinCategory mCategory;
	public ValueKind mKind;         // data pins only; links must connect equal kinds (or a defined implicit conversion)
	public Value mDefault;          // value of an unconnected input data pin
}
