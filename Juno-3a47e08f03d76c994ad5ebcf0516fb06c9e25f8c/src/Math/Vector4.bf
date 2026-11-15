namespace Juno;

using System;

[CRepr]
struct Vector4
{
	public float[4] mValues;

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

	public float mZ
	{
		[Inline] get => this.mValues[2];
		[Inline] set mut => this.mValues[2] = value;
	}

	public float mW
	{
		[Inline] get => this.mValues[3];
		[Inline] set mut => this.mValues[3] = value;
	}

	static public Vector4 sZero = Vector4(0.0f, 0.0f, 0.0f, 0.0f);
	static public Vector4 sOne = Vector4(1.0f, 1.0f, 1.0f, 1.0f);

	public this(float x, float y, float z, float w)
	{
		this.mValues = float[4](x, y, z, w);
	}

	public this(Vector3 xyz, float w)
	{
		this.mValues = float[4](xyz.mX, xyz.mY, xyz.mZ, w);
	}

	public float mMagnitudeSquared
	{
		[Inline] get => ((this.mX * this.mX + this.mY * this.mY) + this.mZ * this.mZ) + this.mW * this.mW;
	}

	public float mMagnitude
	{
		[Inline] get => Math.Sqrt(this.mMagnitudeSquared);
	}

	public Vector4 mNormalized
	{
		[Inline] get
		{
			float magnitude = this.mMagnitude;
			if (magnitude <= Math.[Friend]sMachineEpsilonFloat)
				return Vector4.sZero;
			return this / magnitude;
		}
	}

	public void Normalize() mut
	{
		float magnitude = this.mMagnitude;
		if (magnitude <= Math.[Friend]sMachineEpsilonFloat)
		{
			this.mX = 0.0f;
			this.mY = 0.0f;
			this.mZ = 0.0f;
			this.mW = 0.0f;
		}
		else
		{
			this.mX = this.mX / magnitude;
			this.mY = this.mY / magnitude;
			this.mZ = this.mZ / magnitude;
			this.mW = this.mW / magnitude;
		}
	}

	static public float Dot(Vector4 lhs, Vector4 rhs)
	{
		return ((lhs.mX * rhs.mX + lhs.mY * rhs.mY) + lhs.mZ * rhs.mZ) + lhs.mW * rhs.mW;
	}

	static public Vector4 Lerp(Vector4 lhs, Vector4 rhs, float t)
	{
		var tt = Math.Max(0.0f, Math.Min(1.0f, t));
		return lhs + (rhs - lhs) * tt;
	}

	static public Vector4 Min(Vector4 lhs, Vector4 rhs)
	{
		return Vector4(Math.Min(lhs.mX, rhs.mX), Math.Min(lhs.mY, rhs.mY), Math.Min(lhs.mZ, rhs.mZ), Math.Min(lhs.mW, rhs.mW));
	}

	static public Vector4 Max(Vector4 lhs, Vector4 rhs)
	{
		return Vector4(Math.Max(lhs.mX, rhs.mX), Math.Max(lhs.mY, rhs.mY), Math.Max(lhs.mZ, rhs.mZ), Math.Max(lhs.mW, rhs.mW));
	}

	static public Vector4 Clamp(Vector4 value, Vector4 min, Vector4 max)
	{
		return Min(Max(value, min), max);
	}

	static public Vector4 Transform(Vector4 value, Matrix4x4 matrix)
	{
		return Vector4(
			value.mX * matrix.m11 + value.mY * matrix.m21 + value.mZ * matrix.m31 + value.mW * matrix.m41,
			value.mX * matrix.m12 + value.mY * matrix.m22 + value.mZ * matrix.m32 + value.mW * matrix.m42,
			value.mX * matrix.m13 + value.mY * matrix.m23 + value.mZ * matrix.m33 + value.mW * matrix.m43,
			value.mX * matrix.m14 + value.mY * matrix.m24 + value.mZ * matrix.m34 + value.mW * matrix.m44
		);
	}

	static public bool operator ==(Vector4 lhs, Vector4 rhs)
	{
		return lhs.mX == rhs.mX && lhs.mY == rhs.mY && lhs.mZ == rhs.mZ && lhs.mW == rhs.mW;
	}

	static public bool operator !=(Vector4 lhs, Vector4 rhs)
	{
		return !(lhs == rhs);
	}

	static public Vector4 operator +(Vector4 lhs, Vector4 rhs)
	{
		return Vector4(lhs.mX + rhs.mX, lhs.mY + rhs.mY, lhs.mZ + rhs.mZ, lhs.mW + rhs.mW);
	}

	static public Vector4 operator -(Vector4 lhs, Vector4 rhs)
	{
		return Vector4(lhs.mX - rhs.mX, lhs.mY - rhs.mY, lhs.mZ - rhs.mZ, lhs.mW - rhs.mW);
	}

	static public Vector4 operator -(Vector4 value)
	{
		return Vector4(-value.mX, -value.mY, -value.mZ, -value.mW);
	}

	static public Vector4 operator *(Vector4 lhs, Vector4 rhs)
	{
		return Vector4(lhs.mX * rhs.mX, lhs.mY * rhs.mY, lhs.mZ * rhs.mZ, lhs.mW * rhs.mW);
	}

	static public Vector4 operator *(Vector4 value, float scale)
	{
		return Vector4(value.mX * scale, value.mY * scale, value.mZ * scale, value.mW * scale);
	}

	static public Vector4 operator *(float scale, Vector4 value)
	{
		return value * scale;
	}

	static public Vector4 operator /(Vector4 lhs, Vector4 rhs)
	{
		return Vector4(lhs.mX / rhs.mX, lhs.mY / rhs.mY, lhs.mZ / rhs.mZ, lhs.mW / rhs.mW);
	}

	static public Vector4 operator /(Vector4 value, float divisor)
	{
		return Vector4(value.mX / divisor, value.mY / divisor, value.mZ / divisor, value.mW / divisor);
	}
}
