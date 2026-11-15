namespace Shell.Render;

using System;
using Juno;
using Shell.Core;

static class ColorConvert
{
	// Color values of the model are floats (0..1); the batch renderer takes 8 bit colors.
	static public Color To(Value value)
	{
		return Color(value.mX, value.mY, value.mZ, value.mW);
	}
}
