namespace Juno;

using System;

[CRepr]
struct Quaternion
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

	static public Quaternion sZero = Quaternion(0.0f, 0.0f, 0.0f, 0.0f);
	static public Quaternion sIdentity = Quaternion(0.0f, 0.0f, 0.0f, 1.0f);

	public this(float x, float y, float z, float w)
	{
		this.mValues = float[4](x, y, z, w);
	}

	public this(Matrix3x3 rotationMatrix)
	{
		Quaternion q = FromRotationMatrix(rotationMatrix);
		this.mValues = float[4](q.mX, q.mY, q.mZ, q.mW);
	}

	public this(Matrix4x4 rotationMatrix)
	{
		Quaternion q = FromRotationMatrix(Matrix3x3(rotationMatrix));
		this.mValues = float[4](q.mX, q.mY, q.mZ, q.mW);
	}

	public float mMagnitudeSquared
	{
		[Inline] get => ((this.mX * this.mX + this.mY * this.mY) + this.mZ * this.mZ) + this.mW * this.mW;
	}

	public float mMagnitude
	{
		[Inline] get => Math.Sqrt(this.mMagnitudeSquared);
	}

	public Quaternion mNormalized
	{
		[Inline] get
		{
			float magnitude = this.mMagnitude;
			if (magnitude <= Math.[Friend]sMachineEpsilonFloat)
				return Quaternion.sIdentity;
			return this / magnitude;
		}
	}

	public Quaternion mConjugated
	{
		[Inline] get => Quaternion(-this.mX, -this.mY, -this.mZ, this.mW);
	}

	public Quaternion mInverse
	{
		[Inline] get
		{
			Quaternion result;
			if (!this.TryInvert(out result))
				return Quaternion.sIdentity;
			return result;
		}
	}

	public bool mIsIdentity
	{
		[Inline] get => Math.Abs(this.mX) <= Math.[Friend]sMachineEpsilonFloat && Math.Abs(this.mY) <= Math.[Friend]sMachineEpsilonFloat && Math.Abs(this.mZ) <= Math.[Friend]sMachineEpsilonFloat && Math.Abs(Math.Abs(this.mW) - 1.0f) <= Math.[Friend]sMachineEpsilonFloat;
	}

	public void Normalize() mut
	{
		float magnitude = this.mMagnitude;
		if (magnitude <= Math.[Friend]sMachineEpsilonFloat)
		{
			this.mX = 0.0f;
			this.mY = 0.0f;
			this.mZ = 0.0f;
			this.mW = 1.0f;
		}
		else
		{
			this.mX = this.mX / magnitude;
			this.mY = this.mY / magnitude;
			this.mZ = this.mZ / magnitude;
			this.mW = this.mW / magnitude;
		}
	}

	public bool TryInvert(out Quaternion result)
	{
		float magnitudeSquared = this.mMagnitudeSquared;
		if (magnitudeSquared <= Math.[Friend]sMachineEpsilonFloat * Math.[Friend]sMachineEpsilonFloat)
		{
			result = Quaternion.sIdentity;
			return false;
		}
		result = Quaternion(-this.mX / magnitudeSquared, -this.mY / magnitudeSquared, -this.mZ / magnitudeSquared, this.mW / magnitudeSquared);
		return true;
	}

	static public float Dot(Quaternion lhs, Quaternion rhs)
	{
		return ((lhs.mX * rhs.mX + lhs.mY * rhs.mY) + lhs.mZ * rhs.mZ) + lhs.mW * rhs.mW;
	}

	static public float Angle(Quaternion lhs, Quaternion rhs)
	{
		float cosine = Math.Abs(Dot(lhs.mNormalized, rhs.mNormalized));
		cosine = Math.Max(-1.0f, Math.Min(1.0f, cosine));
		return 2.0f * Math.Acos(cosine);
	}

	static public Quaternion RotateTowards(Quaternion from, Quaternion to, float maxRadiansDelta)
	{
		float angle = Angle(from, to);
		if (angle <= Math.[Friend]sMachineEpsilonFloat)
			return to.mNormalized;
		float t = Math.Max(0.0f, maxRadiansDelta) / angle;
		return Slerp(from, to, Math.Min(1.0f, t));
	}

	static public Quaternion FromAxisAngle(Vector3 axis, float angleRadians)
	{
		Vector3 unitAxis = axis.mNormalized;
		if (unitAxis.mMagnitudeSquared <= Math.[Friend]sMachineEpsilonFloat)
			return Quaternion.sIdentity;
		float halfAngle = angleRadians * 0.5f;
		float sine = Math.Sin(halfAngle);
		return Quaternion(unitAxis.mX * sine, unitAxis.mY * sine, unitAxis.mZ * sine, Math.Cos(halfAngle));
	}

	static public Quaternion FromYawPitchRoll(float yawRadians, float pitchRadians, float rollRadians)
	{
		float halfYaw = yawRadians * 0.5f;
		float halfPitch = pitchRadians * 0.5f;
		float halfRoll = rollRadians * 0.5f;
		float sy = Math.Sin(halfYaw);
		float cy = Math.Cos(halfYaw);
		float sp = Math.Sin(halfPitch);
		float cp = Math.Cos(halfPitch);
		float sr = Math.Sin(halfRoll);
		float cr = Math.Cos(halfRoll);
		return Quaternion(
			cy * sp * cr + sy * cp * sr,
			sy * cp * cr - cy * sp * sr,
			cy * cp * sr - sy * sp * cr,
			cy * cp * cr + sy * sp * sr
		).mNormalized;
	}

	static public Quaternion FromToRotation(Vector3 from, Vector3 to)
	{
		Vector3 a = from.mNormalized;
		Vector3 b = to.mNormalized;
		if (a.mMagnitudeSquared <= Math.[Friend]sMachineEpsilonFloat || b.mMagnitudeSquared <= Math.[Friend]sMachineEpsilonFloat)
			return Quaternion.sIdentity;

		float dot = Vector3.Dot(a, b);
		if (dot >= 1.0f - Math.[Friend]sMachineEpsilonFloat)
			return Quaternion.sIdentity;
		if (dot <= -1.0f + Math.[Friend]sMachineEpsilonFloat)
		{
			Vector3 axis = Vector3.Cross(a, Vector3.sUnitX);
			if (axis.mMagnitudeSquared <= Math.[Friend]sMachineEpsilonFloat)
				axis = Vector3.Cross(a, Vector3.sUnitY);
			return FromAxisAngle(axis, Math.PI_f);
		}

		Vector3 cross = Vector3.Cross(a, b);
		return Quaternion(cross.mX, cross.mY, cross.mZ, 1.0f + dot).mNormalized;
	}

	static public Quaternion LookRotation(Vector3 forward, Vector3 up)
	{
		Vector3 zAxis = forward.mNormalized;
		if (zAxis.mMagnitudeSquared <= Math.[Friend]sMachineEpsilonFloat)
			return Quaternion.sIdentity;
		Vector3 xAxis = Vector3.Cross(up, zAxis).mNormalized;
		if (xAxis.mMagnitudeSquared <= Math.[Friend]sMachineEpsilonFloat)
		{
			Vector3 fallbackUp = Math.Abs(zAxis.mY) < 0.999f ? Vector3.sUp : Vector3.sRight;
			xAxis = Vector3.Cross(fallbackUp, zAxis).mNormalized;
		}
		Vector3 yAxis = Vector3.Cross(zAxis, xAxis);
		return Quaternion(Matrix3x3(
			xAxis.mX, xAxis.mY, xAxis.mZ,
			yAxis.mX, yAxis.mY, yAxis.mZ,
			zAxis.mX, zAxis.mY, zAxis.mZ
		));
	}

	static public Quaternion Lerp(Quaternion lhs, Quaternion rhs, float t)
	{
		// TODO: Refactor
		var rhs;
		var tt = Math.Max(0.0f, Math.Min(1.0f, t));
		if (Dot(lhs, rhs) < 0.0f)
			rhs = -rhs;
		return (lhs + (rhs - lhs) * tt).mNormalized;
	}

	static public Quaternion Slerp(Quaternion lhs, Quaternion rhs, float t)
	{
		var t;
		var lhs;
		var rhs;
		t = Math.Max(0.0f, Math.Min(1.0f, t));
		lhs = lhs.mNormalized;
		rhs = rhs.mNormalized;
		float cosine = Dot(lhs, rhs);
		if (cosine < 0.0f)
		{
			rhs = -rhs;
			cosine = -cosine;
		}
		if (cosine > 0.9995f)
			return (lhs + (rhs - lhs) * t).mNormalized;

		cosine = Math.Max(-1.0f, Math.Min(1.0f, cosine));
		float angle = Math.Acos(cosine);
		float sine = Math.Sin(angle);
		float leftWeight = Math.Sin((1.0f - t) * angle) / sine;
		float rightWeight = Math.Sin(t * angle) / sine;
		return (lhs * leftWeight + rhs * rightWeight).mNormalized;
	}

	static public Quaternion FromRotationMatrix(Matrix3x3 matrix)
	{
		float trace = matrix.m11 + matrix.m22 + matrix.m33;
		if (trace > 0.0f)
		{
			float s = Math.Sqrt(trace + 1.0f) * 2.0f;
			return Quaternion(
				(matrix.m23 - matrix.m32) / s,
				(matrix.m31 - matrix.m13) / s,
				(matrix.m12 - matrix.m21) / s,
				0.25f * s
			).mNormalized;
		}
		if (matrix.m11 > matrix.m22 && matrix.m11 > matrix.m33)
		{
			float s = Math.Sqrt(1.0f + matrix.m11 - matrix.m22 - matrix.m33) * 2.0f;
			return Quaternion(
				0.25f * s,
				(matrix.m12 + matrix.m21) / s,
				(matrix.m13 + matrix.m31) / s,
				(matrix.m23 - matrix.m32) / s
			).mNormalized;
		}
		if (matrix.m22 > matrix.m33)
		{
			float s = Math.Sqrt(1.0f + matrix.m22 - matrix.m11 - matrix.m33) * 2.0f;
			return Quaternion(
				(matrix.m12 + matrix.m21) / s,
				0.25f * s,
				(matrix.m23 + matrix.m32) / s,
				(matrix.m31 - matrix.m13) / s
			).mNormalized;
		}
		else
		{
			float s = Math.Sqrt(1.0f + matrix.m33 - matrix.m11 - matrix.m22) * 2.0f;
			return Quaternion(
				(matrix.m13 + matrix.m31) / s,
				(matrix.m23 + matrix.m32) / s,
				0.25f * s,
				(matrix.m12 - matrix.m21) / s
			).mNormalized;
		}
	}

	static public bool operator ==(Quaternion lhs, Quaternion rhs)
	{
		return lhs.mX == rhs.mX && lhs.mY == rhs.mY && lhs.mZ == rhs.mZ && lhs.mW == rhs.mW;
	}

	static public bool operator !=(Quaternion lhs, Quaternion rhs)
	{
		return !(lhs == rhs);
	}

	static public Quaternion operator +(Quaternion lhs, Quaternion rhs)
	{
		return Quaternion(lhs.mX + rhs.mX, lhs.mY + rhs.mY, lhs.mZ + rhs.mZ, lhs.mW + rhs.mW);
	}

	static public Quaternion operator -(Quaternion lhs, Quaternion rhs)
	{
		return Quaternion(lhs.mX - rhs.mX, lhs.mY - rhs.mY, lhs.mZ - rhs.mZ, lhs.mW - rhs.mW);
	}

	static public Quaternion operator -(Quaternion value)
	{
		return Quaternion(-value.mX, -value.mY, -value.mZ, -value.mW);
	}

	static public Quaternion operator *(Quaternion lhs, Quaternion rhs)
	{
		return Quaternion(
			lhs.mW * rhs.mX + lhs.mX * rhs.mW + lhs.mY * rhs.mZ - lhs.mZ * rhs.mY,
			lhs.mW * rhs.mY - lhs.mX * rhs.mZ + lhs.mY * rhs.mW + lhs.mZ * rhs.mX,
			lhs.mW * rhs.mZ + lhs.mX * rhs.mY - lhs.mY * rhs.mX + lhs.mZ * rhs.mW,
			lhs.mW * rhs.mW - lhs.mX * rhs.mX - lhs.mY * rhs.mY - lhs.mZ * rhs.mZ
		);
	}

	static public Quaternion operator *(Quaternion value, float scale)
	{
		return Quaternion(value.mX * scale, value.mY * scale, value.mZ * scale, value.mW * scale);
	}

	static public Quaternion operator /(Quaternion value, float divisor)
	{
		return Quaternion(value.mX / divisor, value.mY / divisor, value.mZ / divisor, value.mW / divisor);
	}

	static public Vector3 operator *(Quaternion rotation, Vector3 value)
	{
		return Vector3.Transform(value, rotation);
	}
}
