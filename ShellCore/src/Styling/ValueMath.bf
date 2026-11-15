namespace Shell.Styling;

using System;
using Shell.Core;

// Arithmetic on Value for the kinds that support it (Float, Int as float, Vector2, Color, Rect). Other kinds only support Replace.
static class ValueMath
{
	static public bool IsNumeric(ValueKind kind)
	{
		switch (kind)
		{
		case .Float, .Int, .Vector2, .Color, .Rect: return true;
		default: return false;
		}
	}

	static public Value Lerp(Value a, Value b, float t)
	{
		if (t >= 1) return b;
		if (t <= 0) return a;
		if (!IsNumeric(a.mKind) || a.mKind != b.mKind && !(a.mKind == .Float && b.mKind == .Int) && !(a.mKind == .Int && b.mKind == .Float))
			return (t >= 0.5f) ? b : a;     // not interpolatable: switch at the half way point

		switch (b.mKind)
		{
		case .Float, .Int:
			return Value.FromFloat(a.AsFloat() + (b.AsFloat() - a.AsFloat()) * (double)t);
		case .Vector2:
			return Value.FromVector2(a.mX + (b.mX - a.mX) * t, a.mY + (b.mY - a.mY) * t);
		case .Color:
			return Value.FromColor(a.mX + (b.mX - a.mX) * t, a.mY + (b.mY - a.mY) * t, a.mZ + (b.mZ - a.mZ) * t, a.mW + (b.mW - a.mW) * t);
		case .Rect:
			return Value.FromRect(a.mX + (b.mX - a.mX) * t, a.mY + (b.mY - a.mY) * t, a.mZ + (b.mZ - a.mZ) * t, a.mW + (b.mW - a.mW) * t);
		default:
			return b;
		}
	}

	// a + b * weight. Unsupported kinds leave `a` unchanged.
	static public Value AddScaled(Value a, Value b, float weight)
	{
		if (!IsNumeric(b.mKind) || a.mKind != b.mKind && !(a.mKind == .Float && b.mKind == .Int))
			return a;

		switch (b.mKind)
		{
		case .Float, .Int:
			return Value.FromFloat(a.AsFloat() + b.AsFloat() * (double)weight);
		case .Vector2:
			return Value.FromVector2(a.mX + b.mX * weight, a.mY + b.mY * weight);
		case .Color:
			return Value.FromColor(a.mX + b.mX * weight, a.mY + b.mY * weight, a.mZ + b.mZ * weight, a.mW + b.mW * weight);
		case .Rect:
			return Value.FromRect(a.mX + b.mX * weight, a.mY + b.mY * weight, a.mZ + b.mZ * weight, a.mW + b.mW * weight);
		default:
			return a;
		}
	}

	// a * lerp(1, b, weight), component-wise.
	static public Value MultiplyBy(Value a, Value b, float weight)
	{
		if (!IsNumeric(b.mKind) || a.mKind != b.mKind && !(a.mKind == .Float && b.mKind == .Int))
			return a;

		let w = weight;
		switch (b.mKind)
		{
		case .Float, .Int:
			return Value.FromFloat(a.AsFloat() * (1.0 + (b.AsFloat() - 1.0) * (double)w));
		case .Vector2:
			return Value.FromVector2(a.mX * (1 + (b.mX - 1) * w), a.mY * (1 + (b.mY - 1) * w));
		case .Color:
			return Value.FromColor(a.mX * (1 + (b.mX - 1) * w), a.mY * (1 + (b.mY - 1) * w), a.mZ * (1 + (b.mZ - 1) * w), a.mW * (1 + (b.mW - 1) * w));
		case .Rect:
			return Value.FromRect(a.mX * (1 + (b.mX - 1) * w), a.mY * (1 + (b.mY - 1) * w), a.mZ * (1 + (b.mZ - 1) * w), a.mW * (1 + (b.mW - 1) * w));
		default:
			return a;
		}
	}
}
