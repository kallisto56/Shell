namespace Juno;

using System;

[CRepr]
struct Vector3
{
	public float[3] mValues;

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

	static public Vector3 sZero = Vector3(0.0f, 0.0f, 0.0f);
	static public Vector3 sOne = Vector3(1.0f, 1.0f, 1.0f);
	static public Vector3 sUnitX = Vector3(1.0f, 0.0f, 0.0f);
	static public Vector3 sUnitY = Vector3(0.0f, 1.0f, 0.0f);
	static public Vector3 sUnitZ = Vector3(0.0f, 0.0f, 1.0f);
	static public Vector3 sRight = Vector3(1.0f, 0.0f, 0.0f);
	static public Vector3 sLeft = Vector3(-1.0f, 0.0f, 0.0f);
	static public Vector3 sUp = Vector3(0.0f, 1.0f, 0.0f);
	static public Vector3 sDown = Vector3(0.0f, -1.0f, 0.0f);
	static public Vector3 sForward = Vector3(0.0f, 0.0f, 1.0f);
	static public Vector3 sBack = Vector3(0.0f, 0.0f, -1.0f);

	public this(float x, float y, float z)
	{
		this.mValues = float[3](x, y, z);
	}

	public float mMagnitudeSquared
	{
		[Inline] get => this.mX * this.mX + this.mY * this.mY + this.mZ * this.mZ;
	}

	public float mMagnitude
	{
		[Inline] get => Math.Sqrt(this.mMagnitudeSquared);
	}

	public Vector3 mNormalized
	{
		[Inline] get
		{
			float magnitude = this.mMagnitude;
			if (magnitude <= Math.[Friend]sMachineEpsilonFloat)
				return Vector3.sZero;
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
			this.mZ = 0.0f;
		}
		else
		{
			this.mX = this.mX / magnitude;
			this.mY = this.mY / magnitude;
			this.mZ = this.mZ / magnitude;
		}
	}

	static public float Dot(Vector3 lhs, Vector3 rhs)
	{
		return (lhs.mX * rhs.mX + lhs.mY * rhs.mY) + lhs.mZ * rhs.mZ;
	}

	static public Vector3 Cross(Vector3 lhs, Vector3 rhs)
	{
		return Vector3(
			lhs.mY * rhs.mZ - lhs.mZ * rhs.mY,
			lhs.mZ * rhs.mX - lhs.mX * rhs.mZ,
			lhs.mX * rhs.mY - lhs.mY * rhs.mX
		);
	}

	static public float Distance(Vector3 lhs, Vector3 rhs)
	{
		return (rhs - lhs).mMagnitude;
	}

	static public float DistanceSquared(Vector3 lhs, Vector3 rhs)
	{
		return (rhs - lhs).mMagnitudeSquared;
	}

	static public float Angle(Vector3 from, Vector3 to)
	{
		float denominator = Math.Sqrt(from.mMagnitudeSquared * to.mMagnitudeSquared);
		if (denominator <= Math.[Friend]sMachineEpsilonFloat * Math.[Friend]sMachineEpsilonFloat)
			return 0.0f;
		float cosine = Dot(from, to) / denominator;
		cosine = Math.Max(-1.0f, Math.Min(1.0f, cosine));
		return Math.Acos(cosine);
	}

	static public Vector3 Lerp(Vector3 lhs, Vector3 rhs, float t)
	{
		var tt = Math.Max(0.0f, Math.Min(1.0f, t));
		return lhs + (rhs - lhs) * tt;
	}

	static public Vector3 Min(Vector3 lhs, Vector3 rhs)
	{
		return Vector3(Math.Min(lhs.mX, rhs.mX), Math.Min(lhs.mY, rhs.mY), Math.Min(lhs.mZ, rhs.mZ));
	}

	static public Vector3 Max(Vector3 lhs, Vector3 rhs)
	{
		return Vector3(Math.Max(lhs.mX, rhs.mX), Math.Max(lhs.mY, rhs.mY), Math.Max(lhs.mZ, rhs.mZ));
	}

	static public Vector3 Clamp(Vector3 value, Vector3 min, Vector3 max)
	{
		return Min(Max(value, min), max);
	}

	static public Vector3 Reflect(Vector3 direction, Vector3 normal)
	{
		Vector3 unitNormal = normal.mNormalized;
		return direction - unitNormal * (2.0f * Dot(direction, unitNormal));
	}

	static public Vector3 MoveTowards(Vector3 current, Vector3 target, float maxDistanceDelta)
	{
		Vector3 delta = target - current;
		float distance = delta.mMagnitude;
		if (distance <= maxDistanceDelta || distance <= Math.[Friend]sMachineEpsilonFloat)
			return target;
		return current + delta / distance * maxDistanceDelta;
	}

	static public Vector3 ClampMagnitude(Vector3 value, float maxLength)
	{
		if (maxLength <= 0.0f)
			return Vector3.sZero;
		if (value.mMagnitudeSquared > maxLength * maxLength)
			return value.mNormalized * maxLength;
		return value;
	}

	static public Vector3 Project(Vector3 value, Vector3 onto)
	{
		float denominator = Dot(onto, onto);
		if (denominator <= Math.[Friend]sMachineEpsilonFloat * Math.[Friend]sMachineEpsilonFloat)
			return Vector3.sZero;
		return onto * (Dot(value, onto) / denominator);
	}

	static public Vector3 ProjectOnPlane(Vector3 value, Vector3 planeNormal)
	{
		return value - Project(value, planeNormal);
	}

	static public Vector3 Slerp(Vector3 lhs, Vector3 rhs, float t)
	{
		var t;
		t = Math.Max(0.0f, Math.Min(1.0f, t));
		float lhsMagnitude = lhs.mMagnitude;
		float rhsMagnitude = rhs.mMagnitude;
		if (lhsMagnitude <= Math.[Friend]sMachineEpsilonFloat || rhsMagnitude <= Math.[Friend]sMachineEpsilonFloat)
			return Lerp(lhs, rhs, t);

		Vector3 from = lhs / lhsMagnitude;
		Vector3 to = rhs / rhsMagnitude;
		float cosine = Math.Max(-1.0f, Math.Min(1.0f, Dot(from, to)));
		Vector3 direction;
		if (cosine > 0.9995f)
			direction = Lerp(from, to, t).mNormalized;
		else if (cosine < -0.9995f)
		{
			Vector3 reference = Math.Abs(from.mX) < 0.9f ? Vector3.sUnitX : Vector3.sUnitY;
			Vector3 orthogonal = Cross(from, reference).mNormalized;
			float angle = Math.PI_f * t;
			direction = from * Math.Cos(angle) + orthogonal * Math.Sin(angle);
		}
		else
		{
			float angle = Math.Acos(cosine);
			float sine = Math.Sin(angle);
			float fromWeight = Math.Sin((1.0f - t) * angle) / sine;
			float toWeight = Math.Sin(t * angle) / sine;
			direction = from * fromWeight + to * toWeight;
		}
		float magnitude = lhsMagnitude + (rhsMagnitude - lhsMagnitude) * t;
		return direction * magnitude;
	}

	static public Vector3 Transform(Vector3 position, Matrix4x4 matrix)
	{
		return Vector3(
			position.mX * matrix.m11 + position.mY * matrix.m21 + position.mZ * matrix.m31 + matrix.m41,
			position.mX * matrix.m12 + position.mY * matrix.m22 + position.mZ * matrix.m32 + matrix.m42,
			position.mX * matrix.m13 + position.mY * matrix.m23 + position.mZ * matrix.m33 + matrix.m43
		);
	}

	static public Vector3 TransformCoordinate(Vector3 position, Matrix4x4 matrix)
	{
		float x = position.mX * matrix.m11 + position.mY * matrix.m21 + position.mZ * matrix.m31 + matrix.m41;
		float y = position.mX * matrix.m12 + position.mY * matrix.m22 + position.mZ * matrix.m32 + matrix.m42;
		float z = position.mX * matrix.m13 + position.mY * matrix.m23 + position.mZ * matrix.m33 + matrix.m43;
		float w = position.mX * matrix.m14 + position.mY * matrix.m24 + position.mZ * matrix.m34 + matrix.m44;
		if (Math.Abs(w) <= Math.[Friend]sMachineEpsilonFloat)
			return Vector3(x, y, z);
		return Vector3(x / w, y / w, z / w);
	}

	static public Vector3 TransformNormal(Vector3 normal, Matrix4x4 matrix)
	{
		return Vector3(
			normal.mX * matrix.m11 + normal.mY * matrix.m21 + normal.mZ * matrix.m31,
			normal.mX * matrix.m12 + normal.mY * matrix.m22 + normal.mZ * matrix.m32,
			normal.mX * matrix.m13 + normal.mY * matrix.m23 + normal.mZ * matrix.m33
		);
	}

	static public Vector3 TransformNormal(Vector3 normal, Matrix3x3 matrix)
	{
		return Vector3(
			normal.mX * matrix.m11 + normal.mY * matrix.m21 + normal.mZ * matrix.m31,
			normal.mX * matrix.m12 + normal.mY * matrix.m22 + normal.mZ * matrix.m32,
			normal.mX * matrix.m13 + normal.mY * matrix.m23 + normal.mZ * matrix.m33
		);
	}

	static public Vector3 Transform(Vector3 value, Quaternion rotation)
	{
		Vector3 qVector = Vector3(rotation.mX, rotation.mY, rotation.mZ);
		Vector3 t = Cross(qVector, value) * 2.0f;
		return value + t * rotation.mW + Cross(qVector, t);
	}

	static public bool operator ==(Vector3 lhs, Vector3 rhs)
	{
		return lhs.mX == rhs.mX && lhs.mY == rhs.mY && lhs.mZ == rhs.mZ;
	}

	static public bool operator !=(Vector3 lhs, Vector3 rhs)
	{
		return !(lhs == rhs);
	}

	static public Vector3 operator +(Vector3 lhs, Vector3 rhs)
	{
		return Vector3(lhs.mX + rhs.mX, lhs.mY + rhs.mY, lhs.mZ + rhs.mZ);
	}

	static public Vector3 operator -(Vector3 lhs, Vector3 rhs)
	{
		return Vector3(lhs.mX - rhs.mX, lhs.mY - rhs.mY, lhs.mZ - rhs.mZ);
	}

	static public Vector3 operator -(Vector3 value)
	{
		return Vector3(-value.mX, -value.mY, -value.mZ);
	}

	static public Vector3 operator *(Vector3 lhs, Vector3 rhs)
	{
		return Vector3(lhs.mX * rhs.mX, lhs.mY * rhs.mY, lhs.mZ * rhs.mZ);
	}

	static public Vector3 operator *(Vector3 value, float scale)
	{
		return Vector3(value.mX * scale, value.mY * scale, value.mZ * scale);
	}

	static public Vector3 operator *(float scale, Vector3 value)
	{
		return value * scale;
	}

	static public Vector3 operator /(Vector3 lhs, Vector3 rhs)
	{
		return Vector3(lhs.mX / rhs.mX, lhs.mY / rhs.mY, lhs.mZ / rhs.mZ);
	}

	static public Vector3 operator /(Vector3 value, float divisor)
	{
		return Vector3(value.mX / divisor, value.mY / divisor, value.mZ / divisor);
	}
}
