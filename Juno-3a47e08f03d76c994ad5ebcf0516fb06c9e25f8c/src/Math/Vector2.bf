namespace Juno;

using System;

[CRepr]
struct Vector2
{
	public float[2] mValues;

	public float mX
	{
		[Inline] get => this.mValues[0];
		[Inline] set mut => this.mValues[0] = value;
	}

	public float mY
	{
		[Inline] get => this.mValues[1];
		[Inline] set mut => this.mValues[1] = value;
	}

	static public Vector2 sZero = Vector2(0.0f, 0.0f);
	static public Vector2 sOne = Vector2(1.0f, 1.0f);
	static public Vector2 sUnitX = Vector2(1.0f, 0.0f);
	static public Vector2 sUnitY = Vector2(0.0f, 1.0f);

	public this(float x, float y)
	{
		this.mValues = float[2](x, y);
	}

	public float mMagnitudeSquared
	{
		[Inline] get => this.mX * this.mX + this.mY * this.mY;
	}

	public float mMagnitude
	{
		[Inline] get => Math.Sqrt(this.mMagnitudeSquared);
	}

	public Vector2 mNormalized
	{
		[Inline] get
		{
			float magnitude = this.mMagnitude;
			if (magnitude <= Math.[Friend]sMachineEpsilonFloat)
				return Vector2.sZero;
			return this / magnitude;
		}
	}

	public bool mIsNormalized
	{
		[Inline] get => Math.Abs(this.mMagnitudeSquared - 1.0f) <= Math.[Friend]sMachineEpsilonFloat * 4.0f;
	}

	public void Normalize() mut
	{
		float magnitude = this.mMagnitude;
		if (magnitude <= Math.[Friend]sMachineEpsilonFloat)
		{
			this.mX = 0.0f;
			this.mY = 0.0f;
		}
		else
		{
			this.mX = this.mX / magnitude;
			this.mY = this.mY / magnitude;
		}
	}

	static public float Dot(Vector2 lhs, Vector2 rhs)
	{
		return lhs.mX * rhs.mX + lhs.mY * rhs.mY;
	}

	static public float Cross(Vector2 lhs, Vector2 rhs)
	{
		return lhs.mX * rhs.mY - lhs.mY * rhs.mX;
	}

	static public float Distance(Vector2 lhs, Vector2 rhs)
	{
		return (rhs - lhs).mMagnitude;
	}

	static public float DistanceSquared(Vector2 lhs, Vector2 rhs)
	{
		return (rhs - lhs).mMagnitudeSquared;
	}

	static public float Angle(Vector2 from, Vector2 to)
	{
		float denominator = Math.Sqrt(from.mMagnitudeSquared * to.mMagnitudeSquared);
		if (denominator <= Math.[Friend]sMachineEpsilonFloat * Math.[Friend]sMachineEpsilonFloat)
			return 0.0f;
		float cosine = Dot(from, to) / denominator;
		cosine = Math.Max(-1.0f, Math.Min(1.0f, cosine));
		return Math.Acos(cosine);
	}

	static public Vector2 Lerp(Vector2 lhs, Vector2 rhs, float t)
	{
		var tt = Math.Max(0.0f, Math.Min(1.0f, t));
		return lhs + (rhs - lhs) * tt;
	}

	static public Vector2 Min(Vector2 lhs, Vector2 rhs)
	{
		return Vector2(Math.Min(lhs.mX, rhs.mX), Math.Min(lhs.mY, rhs.mY));
	}

	static public Vector2 Max(Vector2 lhs, Vector2 rhs)
	{
		return Vector2(Math.Max(lhs.mX, rhs.mX), Math.Max(lhs.mY, rhs.mY));
	}

	static public Vector2 Clamp(Vector2 value, Vector2 min, Vector2 max)
	{
		return Min(Max(value, min), max);
	}

	static public Vector2 Reflect(Vector2 direction, Vector2 normal)
	{
		Vector2 unitNormal = normal.mNormalized;
		return direction - unitNormal * (2.0f * Dot(direction, unitNormal));
	}

	static public Vector2 MoveTowards(Vector2 current, Vector2 target, float maxDistanceDelta)
	{
		Vector2 delta = target - current;
		float distance = delta.mMagnitude;
		if (distance <= maxDistanceDelta || distance <= Math.[Friend]sMachineEpsilonFloat)
			return target;
		return current + delta / distance * maxDistanceDelta;
	}

	static public Vector2 ClampMagnitude(Vector2 value, float maxLength)
	{
		if (maxLength <= 0.0f)
			return Vector2.sZero;
		if (value.mMagnitudeSquared > maxLength * maxLength)
			return value.mNormalized * maxLength;
		return value;
	}

	static public Vector2 Perpendicular(Vector2 value)
	{
		return Vector2(-value.mY, value.mX);
	}

	static public Vector2 Rotate(Vector2 value, float angleRadians)
	{
		float cosine = Math.Cos(angleRadians);
		float sine = Math.Sin(angleRadians);
		return Vector2(value.mX * cosine - value.mY * sine, value.mX * sine + value.mY * cosine);
	}

	static public Vector2 Transform(Vector2 position, Matrix3x2 matrix)
	{
		return Vector2(
			position.mX * matrix.m11 + position.mY * matrix.m21 + matrix.m31,
			position.mX * matrix.m12 + position.mY * matrix.m22 + matrix.m32
		);
	}

	static public bool operator ==(Vector2 lhs, Vector2 rhs)
	{
		return lhs.mX == rhs.mX && lhs.mY == rhs.mY;
	}

	static public bool operator !=(Vector2 lhs, Vector2 rhs)
	{
		return !(lhs == rhs);
	}

	static public Vector2 operator +(Vector2 lhs, Vector2 rhs)
	{
		return Vector2(lhs.mX + rhs.mX, lhs.mY + rhs.mY);
	}

	static public Vector2 operator -(Vector2 lhs, Vector2 rhs)
	{
		return Vector2(lhs.mX - rhs.mX, lhs.mY - rhs.mY);
	}

	static public Vector2 operator -(Vector2 value)
	{
		return Vector2(-value.mX, -value.mY);
	}

	static public Vector2 operator *(Vector2 lhs, Vector2 rhs)
	{
		return Vector2(lhs.mX * rhs.mX, lhs.mY * rhs.mY);
	}

	static public Vector2 operator *(Vector2 value, float scale)
	{
		return Vector2(value.mX * scale, value.mY * scale);
	}

	static public Vector2 operator *(float scale, Vector2 value)
	{
		return value * scale;
	}

	static public Vector2 operator /(Vector2 lhs, Vector2 rhs)
	{
		return Vector2(lhs.mX / rhs.mX, lhs.mY / rhs.mY);
	}

	static public Vector2 operator /(Vector2 value, float divisor)
	{
		return Vector2(value.mX / divisor, value.mY / divisor);
	}
}
