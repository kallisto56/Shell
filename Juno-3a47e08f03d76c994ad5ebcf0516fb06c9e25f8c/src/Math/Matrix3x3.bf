namespace Juno;

using System;

[CRepr]
struct Matrix3x3
{
	public float[9] mValues;

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
	public float m13
	{
		[Inline] get => this.mValues[2];
		[Inline] set mut => this.mValues[2] = value;
	}
	public float m21
	{
		[Inline] get => this.mValues[3];
		[Inline] set mut => this.mValues[3] = value;
	}
	public float m22
	{
		[Inline] get => this.mValues[4];
		[Inline] set mut => this.mValues[4] = value;
	}
	
	public float m23
	{
		[Inline] get => this.mValues[5];
		[Inline] set mut => this.mValues[5] = value;
	}
	
	public float m31
	{
		[Inline] get => this.mValues[6];
		[Inline] set mut => this.mValues[6] = value;
	}
	
	public float m32
	{
		[Inline] get => this.mValues[7];
		[Inline] set mut => this.mValues[7] = value;
	}
	
	public float m33
	{
		[Inline] get => this.mValues[8];
		[Inline] set mut => this.mValues[8] = value;
	}

	static public Matrix3x3 sZero = Matrix3x3(0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f);
	static public Matrix3x3 sIdentity = Matrix3x3(1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f);

	public this(float m11, float m12, float m13, float m21, float m22, float m23, float m31, float m32, float m33)
	{
		this.mValues = float[9](m11, m12, m13, m21, m22, m23, m31, m32, m33);
	}

	public this(Quaternion rotation)
	{
		Quaternion q = rotation.mNormalized;
		float xx = q.mX * q.mX;
		float yy = q.mY * q.mY;
		float zz = q.mZ * q.mZ;
		float xy = q.mX * q.mY;
		float xz = q.mX * q.mZ;
		float yz = q.mY * q.mZ;
		float xw = q.mX * q.mW;
		float yw = q.mY * q.mW;
		float zw = q.mZ * q.mW;
		this.mValues = float[9](
			1.0f - 2.0f * (yy + zz), 2.0f * (xy + zw), 2.0f * (xz - yw),
			2.0f * (xy - zw), 1.0f - 2.0f * (xx + zz), 2.0f * (yz + xw),
			2.0f * (xz + yw), 2.0f * (yz - xw), 1.0f - 2.0f * (xx + yy)
		);
	}

	public this(Matrix4x4 matrix)
	{
		this.mValues = float[9](matrix.m11, matrix.m12, matrix.m13, matrix.m21, matrix.m22, matrix.m23, matrix.m31, matrix.m32, matrix.m33);
	}

	
	public bool mIsIdentity
	{
		[Inline] get => this == Matrix3x3.sIdentity;
	}

	
	public float mDeterminant
	{
		[Inline] get =>
			this.m11 * (this.m22 * this.m33 - this.m23 * this.m32) -
			this.m12 * (this.m21 * this.m33 - this.m23 * this.m31) +
			this.m13 * (this.m21 * this.m32 - this.m22 * this.m31);
	}

	
	public Matrix3x3 mTransposed
	{
		[Inline] get => Matrix3x3(
			this.m11, this.m21, this.m31,
			this.m12, this.m22, this.m32,
			this.m13, this.m23, this.m33
		);
	}

	
	public Matrix3x3 mInverse
	{
		[Inline] get
		{
			Matrix3x3 result;
			if (!this.TryInvert(out result))
				return Matrix3x3.sZero;
			return result;
		}
	}

	public bool TryInvert(out Matrix3x3 result)
	{
		float c11 = this.m22 * this.m33 - this.m23 * this.m32;
		float c12 = this.m23 * this.m31 - this.m21 * this.m33;
		float c13 = this.m21 * this.m32 - this.m22 * this.m31;
		float determinant = this.m11 * c11 + this.m12 * c12 + this.m13 * c13;
		if (determinant == 0.0f)
		{
			result = Matrix3x3.sZero;
			return false;
		}

		float inverseDeterminant = 1.0f / determinant;
		result = Matrix3x3(
			c11 * inverseDeterminant,
			(this.m13 * this.m32 - this.m12 * this.m33) * inverseDeterminant,
			(this.m12 * this.m23 - this.m13 * this.m22) * inverseDeterminant,
			c12 * inverseDeterminant,
			(this.m11 * this.m33 - this.m13 * this.m31) * inverseDeterminant,
			(this.m13 * this.m21 - this.m11 * this.m23) * inverseDeterminant,
			c13 * inverseDeterminant,
			(this.m12 * this.m31 - this.m11 * this.m32) * inverseDeterminant,
			(this.m11 * this.m22 - this.m12 * this.m21) * inverseDeterminant
		);
		return true;
	}

	static public Matrix3x3 CreateScale(Vector3 scale)
	{
		return Matrix3x3(scale.mX, 0.0f, 0.0f, 0.0f, scale.mY, 0.0f, 0.0f, 0.0f, scale.mZ);
	}

	static public Matrix3x3 CreateRotationX(float angleRadians)
	{
		float cosine = Math.Cos(angleRadians);
		float sine = Math.Sin(angleRadians);
		return Matrix3x3(1.0f, 0.0f, 0.0f, 0.0f, cosine, sine, 0.0f, -sine, cosine);
	}

	static public Matrix3x3 CreateRotationY(float angleRadians)
	{
		float cosine = Math.Cos(angleRadians);
		float sine = Math.Sin(angleRadians);
		return Matrix3x3(cosine, 0.0f, -sine, 0.0f, 1.0f, 0.0f, sine, 0.0f, cosine);
	}

	static public Matrix3x3 CreateRotationZ(float angleRadians)
	{
		float cosine = Math.Cos(angleRadians);
		float sine = Math.Sin(angleRadians);
		return Matrix3x3(cosine, sine, 0.0f, -sine, cosine, 0.0f, 0.0f, 0.0f, 1.0f);
	}

	static public bool operator ==(Matrix3x3 lhs, Matrix3x3 rhs)
	{
		return lhs.m11 == rhs.m11 && lhs.m12 == rhs.m12 && lhs.m13 == rhs.m13 &&
			lhs.m21 == rhs.m21 && lhs.m22 == rhs.m22 && lhs.m23 == rhs.m23 &&
			lhs.m31 == rhs.m31 && lhs.m32 == rhs.m32 && lhs.m33 == rhs.m33;
	}

	static public bool operator !=(Matrix3x3 lhs, Matrix3x3 rhs)
	{
		return !(lhs == rhs);
	}

	static public Matrix3x3 operator +(Matrix3x3 lhs, Matrix3x3 rhs)
	{
		return Matrix3x3(
			lhs.m11 + rhs.m11, lhs.m12 + rhs.m12, lhs.m13 + rhs.m13,
			lhs.m21 + rhs.m21, lhs.m22 + rhs.m22, lhs.m23 + rhs.m23,
			lhs.m31 + rhs.m31, lhs.m32 + rhs.m32, lhs.m33 + rhs.m33
		);
	}

	static public Matrix3x3 operator -(Matrix3x3 lhs, Matrix3x3 rhs)
	{
		return Matrix3x3(
			lhs.m11 - rhs.m11, lhs.m12 - rhs.m12, lhs.m13 - rhs.m13,
			lhs.m21 - rhs.m21, lhs.m22 - rhs.m22, lhs.m23 - rhs.m23,
			lhs.m31 - rhs.m31, lhs.m32 - rhs.m32, lhs.m33 - rhs.m33
		);
	}

	static public Matrix3x3 operator *(Matrix3x3 lhs, Matrix3x3 rhs)
	{
		return Matrix3x3(
			lhs.m11 * rhs.m11 + lhs.m12 * rhs.m21 + lhs.m13 * rhs.m31,
			lhs.m11 * rhs.m12 + lhs.m12 * rhs.m22 + lhs.m13 * rhs.m32,
			lhs.m11 * rhs.m13 + lhs.m12 * rhs.m23 + lhs.m13 * rhs.m33,
			lhs.m21 * rhs.m11 + lhs.m22 * rhs.m21 + lhs.m23 * rhs.m31,
			lhs.m21 * rhs.m12 + lhs.m22 * rhs.m22 + lhs.m23 * rhs.m32,
			lhs.m21 * rhs.m13 + lhs.m22 * rhs.m23 + lhs.m23 * rhs.m33,
			lhs.m31 * rhs.m11 + lhs.m32 * rhs.m21 + lhs.m33 * rhs.m31,
			lhs.m31 * rhs.m12 + lhs.m32 * rhs.m22 + lhs.m33 * rhs.m32,
			lhs.m31 * rhs.m13 + lhs.m32 * rhs.m23 + lhs.m33 * rhs.m33
		);
	}

	static public Matrix3x3 operator *(Matrix3x3 value, float scale)
	{
		return Matrix3x3(
			value.m11 * scale, value.m12 * scale, value.m13 * scale,
			value.m21 * scale, value.m22 * scale, value.m23 * scale,
			value.m31 * scale, value.m32 * scale, value.m33 * scale
		);
	}
}
