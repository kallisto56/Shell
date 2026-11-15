namespace Juno;

using System;
using System.Interop;

[CRepr]
struct ACCENT_POLICY
{
	public ACCENT_STATE AccentState;
	public int32 AccentFlags;
	public uint32 GradientColor;
	public int32 AnimationId;
}
