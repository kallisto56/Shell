namespace Juno;

using System;

[CRepr]
struct Matrix3x2
{
	public float[6] mValues;


	public float m11
	{
		[Inline] get => this.mValues[0];
		[Inline] set mut => this.mValues[0] = value;
	}

	public float m12
	{
		[Inline] get => this.mValues[1];
		[Inline] set mut => this.mValues[1] = value;
	}

	public float m21
	{
		[Inline] get => this.mValues[2];
		[Inline] set mut => this.mValues[2] = value;
	}

	public float m22
	{
		[Inline] get => this.mValues[3];
		[Inline] set mut => this.mValues[3] = value;
	}

	public float m31
	{
		[Inline] get => this.mValues[4];
		[Inline] set mut => this.mValues[4] = value;
	}

	public float m32
	{
		[Inline] get => this.mValues[5];
		[Inline] set mut => this.mValues[5] = value;
	}

	static public Matrix3x2 sZero = Matrix3x2(0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f);
	static public Matrix3x2 sIdentity = Matrix3x2(1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f);

	public this(float m11, float m12, float m21, float m22, float m31, float m32)
	{
		this.mValues = float[6](m11, m12, m21, m22, m31, m32);
	}

	public bool mIsIdentity
	{
		[Inline] get => this == Matrix3x2.sIdentity;
	}

	public float mDeterminant
	{
		[Inline] get => this.m11 * this.m22 - this.m21 * this.m12;
	}

	public Matrix3x2 mInverse
	{
		[Inline] get
		{
			Matrix3x2 result;
			if (!this.TryInvert(out result))
				return Matrix3x2.sZero;
			return result;
		}
	}

	public bool TryInvert(out Matrix3x2 result)
	{
		float determinant = this.mDeterminant;
		if (determinant == 0.0f)
		{
			result = Matrix3x2.sZero;
			return false;
		}

		float inverseDeterminant = 1.0f / determinant;
		float m11 = this.m22 * inverseDeterminant;
		float m12 = -this.m12 * inverseDeterminant;
		float m21 = -this.m21 * inverseDeterminant;
		float m22 = this.m11 * inverseDeterminant;
		float m31 = -(this.m31 * m11 + this.m32 * m21);
		float m32 = -(this.m31 * m12 + this.m32 * m22);
		result = Matrix3x2(m11, m12, m21, m22, m31, m32);
		return true;
	}

	static public Matrix3x2 CreateTranslation(Vector2 translation)
	{
		return Matrix3x2(1.0f, 0.0f, 0.0f, 1.0f, translation.mX, translation.mY);
	}

	static public Matrix3x2 CreateScale(Vector2 scale)
	{
		return Matrix3x2(scale.mX, 0.0f, 0.0f, scale.mY, 0.0f, 0.0f);
	}

	static public Matrix3x2 CreateRotation(float angleRadians)
	{
		float cosine = Math.Cos(angleRadians);
		float sine = Math.Sin(angleRadians);
		return Matrix3x2(cosine, sine, -sine, cosine, 0.0f, 0.0f);
	}

	static public Matrix3x2 CreateRotation(float angleRadians, Vector2 center)
	{
		float cosine = Math.Cos(angleRadians);
		float sine = Math.Sin(angleRadians);
		float tx = center.mX * (1.0f - cosine) + center.mY * sine;
		float ty = center.mY * (1.0f - cosine) - center.mX * sine;
		return Matrix3x2(cosine, sine, -sine, cosine, tx, ty);
	}

	static public Matrix3x2 CreateScale(Vector2 scale, Vector2 center)
	{
		float tx = center.mX * (1.0f - scale.mX);
		float ty = center.mY * (1.0f - scale.mY);
		return Matrix3x2(scale.mX, 0.0f, 0.0f, scale.mY, tx, ty);
	}

	static public bool operator ==(Matrix3x2 lhs, Matrix3x2 rhs)
	{
		return lhs.m11 == rhs.m11 && lhs.m12 == rhs.m12 &&
			lhs.m21 == rhs.m21 && lhs.m22 == rhs.m22 &&
			lhs.m31 == rhs.m31 && lhs.m32 == rhs.m32;
	}

	static public bool operator !=(Matrix3x2 lhs, Matrix3x2 rhs)
	{
		return !(lhs == rhs);
	}

	static public Matrix3x2 operator +(Matrix3x2 lhs, Matrix3x2 rhs)
	{
		return Matrix3x2(
			lhs.m11 + rhs.m11, lhs.m12 + rhs.m12,
			lhs.m21 + rhs.m21, lhs.m22 + rhs.m22,
			lhs.m31 + rhs.m31, lhs.m32 + rhs.m32
		);
	}

	static public Matrix3x2 operator -(Matrix3x2 lhs, Matrix3x2 rhs)
	{
		return Matrix3x2(
			lhs.m11 - rhs.m11, lhs.m12 - rhs.m12,
			lhs.m21 - rhs.m21, lhs.m22 - rhs.m22,
			lhs.m31 - rhs.m31, lhs.m32 - rhs.m32
		);
	}

	static public Matrix3x2 operator *(Matrix3x2 lhs, Matrix3x2 rhs)
	{
		return Matrix3x2(
			lhs.m11 * rhs.m11 + lhs.m12 * rhs.m21,
			lhs.m11 * rhs.m12 + lhs.m12 * rhs.m22,
			lhs.m21 * rhs.m11 + lhs.m22 * rhs.m21,
			lhs.m21 * rhs.m12 + lhs.m22 * rhs.m22,
			lhs.m31 * rhs.m11 + lhs.m32 * rhs.m21 + rhs.m31,
			lhs.m31 * rhs.m12 + lhs.m32 * rhs.m22 + rhs.m32
		);
	}

	static public Matrix3x2 operator *(Matrix3x2 value, float scale)
	{
		return Matrix3x2(
			value.m11 * scale, value.m12 * scale,
			value.m21 * scale, value.m22 * scale,
			value.m31 * scale, value.m32 * scale
		);
	}
}
