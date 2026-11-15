namespace Juno;

using System;

[CRepr]
struct Matrix4x4
{
	public float[16] mValues;

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
	public float m14
	{
		[Inline] get => this.mValues[3];
		[Inline] set mut => this.mValues[3] = value;
	}
	public float m21
	{
		[Inline] get => this.mValues[4];
		[Inline] set mut => this.mValues[4] = value;
	}
	public float m22
	{
		[Inline] get => this.mValues[5];
		[Inline] set mut => this.mValues[5] = value;
	}
	public float m23
	{
		[Inline] get => this.mValues[6];
		[Inline] set mut => this.mValues[6] = value;
	}
	public float m24
	{
		[Inline] get => this.mValues[7];
		[Inline] set mut => this.mValues[7] = value;
	}
	public float m31
	{
		[Inline] get => this.mValues[8];
		[Inline] set mut => this.mValues[8] = value;
	}
	public float m32
	{
		[Inline] get => this.mValues[9];
		[Inline] set mut => this.mValues[9] = value;
	}
	public float m33
	{
		[Inline] get => this.mValues[10];
		[Inline] set mut => this.mValues[10] = value;
	}
	public float m34
	{
		[Inline] get => this.mValues[11];
		[Inline] set mut => this.mValues[11] = value;
	}
	public float m41
	{
		[Inline] get => this.mValues[12];
		[Inline] set mut => this.mValues[12] = value;
	}
	public float m42
	{
		[Inline] get => this.mValues[13];
		[Inline] set mut => this.mValues[13] = value;
	}
	public float m43
	{
		[Inline] get => this.mValues[14];
		[Inline] set mut => this.mValues[14] = value;
	}
	public float m44
	{
		[Inline] get => this.mValues[15];
		[Inline] set mut => this.mValues[15] = value;
	}

	static public Matrix4x4 sZero = Matrix4x4(0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f);
	static public Matrix4x4 sIdentity = Matrix4x4(1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f);

	public this(float m11, float m12, float m13, float m14, float m21, float m22, float m23, float m24, float m31, float m32, float m33, float m34, float m41, float m42, float m43, float m44)
	{
		this.mValues = float[16](m11, m12, m13, m14, m21, m22, m23, m24, m31, m32, m33, m34, m41, m42, m43, m44);
	}

	public this(Quaternion rotation)
	{
		Matrix3x3 r = Matrix3x3(rotation);
		this.mValues = float[16](
			r.m11, r.m12, r.m13, 0.0f,
			r.m21, r.m22, r.m23, 0.0f,
			r.m31, r.m32, r.m33, 0.0f,
			0.0f, 0.0f, 0.0f, 1.0f
		);
	}

	public this(Matrix3x3 rotation)
	{
		this.mValues = float[16](
			rotation.m11, rotation.m12, rotation.m13, 0.0f,
			rotation.m21, rotation.m22, rotation.m23, 0.0f,
			rotation.m31, rotation.m32, rotation.m33, 0.0f,
			0.0f, 0.0f, 0.0f, 1.0f
		);
	}

	public this(Vector3 scale, Quaternion rotation, Vector3 translation)
	{
		Matrix3x3 r = Matrix3x3(rotation);
		this.mValues = float[16](
			r.m11 * scale.mX, r.m12 * scale.mX, r.m13 * scale.mX, 0.0f,
			r.m21 * scale.mY, r.m22 * scale.mY, r.m23 * scale.mY, 0.0f,
			r.m31 * scale.mZ, r.m32 * scale.mZ, r.m33 * scale.mZ, 0.0f,
			translation.mX, translation.mY, translation.mZ, 1.0f
		);
	}

	public bool mIsIdentity
	{
		[Inline] get => this == Matrix4x4.sIdentity;
	}

	public float mDeterminant
	{
		[Inline] get
		{
			Matrix4x4 cofactors = this.GetCofactors();
			return this.m11 * cofactors.m11 + this.m12 * cofactors.m12 + this.m13 * cofactors.m13 + this.m14 * cofactors.m14;
		}
	}

	public Matrix4x4 mTransposed
	{
		[Inline] get => Matrix4x4(
			this.m11, this.m21, this.m31, this.m41,
			this.m12, this.m22, this.m32, this.m42,
			this.m13, this.m23, this.m33, this.m43,
			this.m14, this.m24, this.m34, this.m44
		);
	}

	public Matrix4x4 mInverse
	{
		[Inline] get
		{
			Matrix4x4 result;
			if (!this.TryInvert(out result))
				return Matrix4x4.sZero;
			return result;
		}
	}

	static float Det3(float a11, float a12, float a13, float a21, float a22, float a23, float a31, float a32, float a33)
	{
		return a11 * (a22 * a33 - a23 * a32) - a12 * (a21 * a33 - a23 * a31) + a13 * (a21 * a32 - a22 * a31);
	}

	Matrix4x4 GetCofactors()
	{
		return Matrix4x4(
			Det3(this.m22, this.m23, this.m24, this.m32, this.m33, this.m34, this.m42, this.m43, this.m44),
			-Det3(this.m21, this.m23, this.m24, this.m31, this.m33, this.m34, this.m41, this.m43, this.m44),
			Det3(this.m21, this.m22, this.m24, this.m31, this.m32, this.m34, this.m41, this.m42, this.m44),
			-Det3(this.m21, this.m22, this.m23, this.m31, this.m32, this.m33, this.m41, this.m42, this.m43),
			-Det3(this.m12, this.m13, this.m14, this.m32, this.m33, this.m34, this.m42, this.m43, this.m44),
			Det3(this.m11, this.m13, this.m14, this.m31, this.m33, this.m34, this.m41, this.m43, this.m44),
			-Det3(this.m11, this.m12, this.m14, this.m31, this.m32, this.m34, this.m41, this.m42, this.m44),
			Det3(this.m11, this.m12, this.m13, this.m31, this.m32, this.m33, this.m41, this.m42, this.m43),
			Det3(this.m12, this.m13, this.m14, this.m22, this.m23, this.m24, this.m42, this.m43, this.m44),
			-Det3(this.m11, this.m13, this.m14, this.m21, this.m23, this.m24, this.m41, this.m43, this.m44),
			Det3(this.m11, this.m12, this.m14, this.m21, this.m22, this.m24, this.m41, this.m42, this.m44),
			-Det3(this.m11, this.m12, this.m13, this.m21, this.m22, this.m23, this.m41, this.m42, this.m43),
			-Det3(this.m12, this.m13, this.m14, this.m22, this.m23, this.m24, this.m32, this.m33, this.m34),
			Det3(this.m11, this.m13, this.m14, this.m21, this.m23, this.m24, this.m31, this.m33, this.m34),
			-Det3(this.m11, this.m12, this.m14, this.m21, this.m22, this.m24, this.m31, this.m32, this.m34),
			Det3(this.m11, this.m12, this.m13, this.m21, this.m22, this.m23, this.m31, this.m32, this.m33)
		);
	}

	public bool TryInvert(out Matrix4x4 result)
	{
		Matrix4x4 cofactors = this.GetCofactors();
		float determinant = this.m11 * cofactors.m11 + this.m12 * cofactors.m12 + this.m13 * cofactors.m13 + this.m14 * cofactors.m14;
		if (determinant == 0.0f)
		{
			result = Matrix4x4.sZero;
			return false;
		}

		float inverseDeterminant = 1.0f / determinant;
		result = Matrix4x4(
			cofactors.m11 * inverseDeterminant, cofactors.m21 * inverseDeterminant, cofactors.m31 * inverseDeterminant, cofactors.m41 * inverseDeterminant,
			cofactors.m12 * inverseDeterminant, cofactors.m22 * inverseDeterminant, cofactors.m32 * inverseDeterminant, cofactors.m42 * inverseDeterminant,
			cofactors.m13 * inverseDeterminant, cofactors.m23 * inverseDeterminant, cofactors.m33 * inverseDeterminant, cofactors.m43 * inverseDeterminant,
			cofactors.m14 * inverseDeterminant, cofactors.m24 * inverseDeterminant, cofactors.m34 * inverseDeterminant, cofactors.m44 * inverseDeterminant
		);
		return true;
	}

	static public Matrix4x4 CreateTranslation(Vector3 translation)
	{
		return Matrix4x4(
			1.0f, 0.0f, 0.0f, 0.0f,
			0.0f, 1.0f, 0.0f, 0.0f,
			0.0f, 0.0f, 1.0f, 0.0f,
			translation.mX, translation.mY, translation.mZ, 1.0f
		);
	}

	static public Matrix4x4 CreateScale(Vector3 scale)
	{
		return Matrix4x4(
			scale.mX, 0.0f, 0.0f, 0.0f,
			0.0f, scale.mY, 0.0f, 0.0f,
			0.0f, 0.0f, scale.mZ, 0.0f,
			0.0f, 0.0f, 0.0f, 1.0f
		);
	}

	static public Matrix4x4 CreateRotationX(float angleRadians)
	{
		float cosine = Math.Cos(angleRadians);
		float sine = Math.Sin(angleRadians);
		return Matrix4x4(
			1.0f, 0.0f, 0.0f, 0.0f,
			0.0f, cosine, sine, 0.0f,
			0.0f, -sine, cosine, 0.0f,
			0.0f, 0.0f, 0.0f, 1.0f
		);
	}

	static public Matrix4x4 CreateRotationY(float angleRadians)
	{
		float cosine = Math.Cos(angleRadians);
		float sine = Math.Sin(angleRadians);
		return Matrix4x4(
			cosine, 0.0f, -sine, 0.0f,
			0.0f, 1.0f, 0.0f, 0.0f,
			sine, 0.0f, cosine, 0.0f,
			0.0f, 0.0f, 0.0f, 1.0f
		);
	}

	static public Matrix4x4 CreateRotationZ(float angleRadians)
	{
		float cosine = Math.Cos(angleRadians);
		float sine = Math.Sin(angleRadians);
		return Matrix4x4(
			cosine, sine, 0.0f, 0.0f,
			-sine, cosine, 0.0f, 0.0f,
			0.0f, 0.0f, 1.0f, 0.0f,
			0.0f, 0.0f, 0.0f, 1.0f
		);
	}

	static public Matrix4x4 CreateFromQuaternion(Quaternion rotation)
	{
		return Matrix4x4(rotation);
	}

	static public Matrix4x4 CreateLookAt(Vector3 cameraPosition, Vector3 cameraTarget, Vector3 cameraUpVector)
	{
		Vector3 zAxis = (cameraTarget - cameraPosition).mNormalized;
		if (zAxis.mMagnitudeSquared <= Math.[Friend]sMachineEpsilonFloat)
			return Matrix4x4.sIdentity;
		Vector3 xAxis = Vector3.Cross(cameraUpVector, zAxis).mNormalized;
		if (xAxis.mMagnitudeSquared <= Math.[Friend]sMachineEpsilonFloat)
		{
			Vector3 fallbackUp = Math.Abs(zAxis.mY) < 0.999f ? Vector3.sUp : Vector3.sRight;
			xAxis = Vector3.Cross(fallbackUp, zAxis).mNormalized;
		}
		Vector3 yAxis = Vector3.Cross(zAxis, xAxis);
		return Matrix4x4(
			xAxis.mX, yAxis.mX, zAxis.mX, 0.0f,
			xAxis.mY, yAxis.mY, zAxis.mY, 0.0f,
			xAxis.mZ, yAxis.mZ, zAxis.mZ, 0.0f,
			-Vector3.Dot(xAxis, cameraPosition), -Vector3.Dot(yAxis, cameraPosition), -Vector3.Dot(zAxis, cameraPosition), 1.0f
		);
	}

	static public Matrix4x4 CreatePerspectiveFieldOfView(float fieldOfViewRadians, float aspectRatio, float nearPlane, float farPlane)
	{
		float yScale = 1.0f / Math.Tan(fieldOfViewRadians * 0.5f);
		float xScale = yScale / aspectRatio;
		float depth = farPlane / (farPlane - nearPlane);
		return Matrix4x4(
			xScale, 0.0f, 0.0f, 0.0f,
			0.0f, yScale, 0.0f, 0.0f,
			0.0f, 0.0f, depth, 1.0f,
			0.0f, 0.0f, -nearPlane * depth, 0.0f
		);
	}

	static public Matrix4x4 CreateOrthographic(float width, float height, float nearPlane, float farPlane)
	{
		float depth = 1.0f / (farPlane - nearPlane);
		return Matrix4x4(
			2.0f / width, 0.0f, 0.0f, 0.0f,
			0.0f, 2.0f / height, 0.0f, 0.0f,
			0.0f, 0.0f, depth, 0.0f,
			0.0f, 0.0f, -nearPlane * depth, 1.0f
		);
	}

	static public bool operator ==(Matrix4x4 lhs, Matrix4x4 rhs)
	{
		return lhs.m11 == rhs.m11 && lhs.m12 == rhs.m12 && lhs.m13 == rhs.m13 && lhs.m14 == rhs.m14 &&
			lhs.m21 == rhs.m21 && lhs.m22 == rhs.m22 && lhs.m23 == rhs.m23 && lhs.m24 == rhs.m24 &&
			lhs.m31 == rhs.m31 && lhs.m32 == rhs.m32 && lhs.m33 == rhs.m33 && lhs.m34 == rhs.m34 &&
			lhs.m41 == rhs.m41 && lhs.m42 == rhs.m42 && lhs.m43 == rhs.m43 && lhs.m44 == rhs.m44;
	}

	static public bool operator !=(Matrix4x4 lhs, Matrix4x4 rhs)
	{
		return !(lhs == rhs);
	}

	static public Matrix4x4 operator +(Matrix4x4 lhs, Matrix4x4 rhs)
	{
		return Matrix4x4(
			lhs.m11 + rhs.m11,
			lhs.m12 + rhs.m12,
			lhs.m13 + rhs.m13,
			lhs.m14 + rhs.m14,

			lhs.m21 + rhs.m21,
			lhs.m22 + rhs.m22,
			lhs.m23 + rhs.m23,
			lhs.m24 + rhs.m24,

			lhs.m31 + rhs.m31,
			lhs.m32 + rhs.m32,
			lhs.m33 + rhs.m33,
			lhs.m34 + rhs.m34,

			lhs.m41 + rhs.m41,
			lhs.m42 + rhs.m42,
			lhs.m43 + rhs.m43,
			lhs.m44 + rhs.m44
		);
	}

	static public Matrix4x4 operator -(Matrix4x4 lhs, Matrix4x4 rhs)
	{
		return Matrix4x4(
			lhs.m11 - rhs.m11,
			lhs.m12 - rhs.m12,
			lhs.m13 - rhs.m13,
			lhs.m14 - rhs.m14,

			lhs.m21 - rhs.m21,
			lhs.m22 - rhs.m22,
			lhs.m23 - rhs.m23,
			lhs.m24 - rhs.m24,

			lhs.m31 - rhs.m31,
			lhs.m32 - rhs.m32,
			lhs.m33 - rhs.m33,
			lhs.m34 - rhs.m34,

			lhs.m41 - rhs.m41,
			lhs.m42 - rhs.m42,
			lhs.m43 - rhs.m43,
			lhs.m44 - rhs.m44
		);
	}

	static public Matrix4x4 operator *(Matrix4x4 lhs, Matrix4x4 rhs)
	{
		return Matrix4x4(
			lhs.m11 * rhs.m11 + lhs.m12 * rhs.m21 + lhs.m13 * rhs.m31 + lhs.m14 * rhs.m41,
			lhs.m11 * rhs.m12 + lhs.m12 * rhs.m22 + lhs.m13 * rhs.m32 + lhs.m14 * rhs.m42,
			lhs.m11 * rhs.m13 + lhs.m12 * rhs.m23 + lhs.m13 * rhs.m33 + lhs.m14 * rhs.m43,
			lhs.m11 * rhs.m14 + lhs.m12 * rhs.m24 + lhs.m13 * rhs.m34 + lhs.m14 * rhs.m44,

			lhs.m21 * rhs.m11 + lhs.m22 * rhs.m21 + lhs.m23 * rhs.m31 + lhs.m24 * rhs.m41,
			lhs.m21 * rhs.m12 + lhs.m22 * rhs.m22 + lhs.m23 * rhs.m32 + lhs.m24 * rhs.m42,
			lhs.m21 * rhs.m13 + lhs.m22 * rhs.m23 + lhs.m23 * rhs.m33 + lhs.m24 * rhs.m43,
			lhs.m21 * rhs.m14 + lhs.m22 * rhs.m24 + lhs.m23 * rhs.m34 + lhs.m24 * rhs.m44,

			lhs.m31 * rhs.m11 + lhs.m32 * rhs.m21 + lhs.m33 * rhs.m31 + lhs.m34 * rhs.m41,
			lhs.m31 * rhs.m12 + lhs.m32 * rhs.m22 + lhs.m33 * rhs.m32 + lhs.m34 * rhs.m42,
			lhs.m31 * rhs.m13 + lhs.m32 * rhs.m23 + lhs.m33 * rhs.m33 + lhs.m34 * rhs.m43,
			lhs.m31 * rhs.m14 + lhs.m32 * rhs.m24 + lhs.m33 * rhs.m34 + lhs.m34 * rhs.m44,

			lhs.m41 * rhs.m11 + lhs.m42 * rhs.m21 + lhs.m43 * rhs.m31 + lhs.m44 * rhs.m41,
			lhs.m41 * rhs.m12 + lhs.m42 * rhs.m22 + lhs.m43 * rhs.m32 + lhs.m44 * rhs.m42,
			lhs.m41 * rhs.m13 + lhs.m42 * rhs.m23 + lhs.m43 * rhs.m33 + lhs.m44 * rhs.m43,
			lhs.m41 * rhs.m14 + lhs.m42 * rhs.m24 + lhs.m43 * rhs.m34 + lhs.m44 * rhs.m44
		);
	}

	static public Matrix4x4 operator *(Matrix4x4 value, float scale)
	{
		return Matrix4x4(
			value.m11 * scale,
			value.m12 * scale,
			value.m13 * scale,
			value.m14 * scale,

			value.m21 * scale,
			value.m22 * scale,
			value.m23 * scale,
			value.m24 * scale,

			value.m31 * scale,
			value.m32 * scale,
			value.m33 * scale,
			value.m34 * scale,

			value.m41 * scale,
			value.m42 * scale,
			value.m43 * scale,
			value.m44 * scale
		);
	}
}
