namespace Juno;

using System;

[CRepr]
struct Plane
{
	public Vector3 mNormal;
	public float mD;

	static public Plane sZero = Plane(Vector3.sZero, 0.0f);

	public this(Vector3 normal, float d)
	{
		this.mNormal = normal;
		this.mD = d;
	}

	public this(Vector3 normal, Vector3 point)
	{
		this.mNormal = normal.mNormalized;
		this.mD = -Vector3.Dot(this.mNormal, point);
	}

	public this(Vector3 pointA, Vector3 pointB, Vector3 pointC)
	{
		this.mNormal = Vector3.Cross(pointB - pointA, pointC - pointA).mNormalized;
		this.mD = -Vector3.Dot(this.mNormal, pointA);
	}

	public float mMagnitude
	{
		[Inline] get => this.mNormal.mMagnitude;
	}

	public Plane mNormalized
	{
		[Inline] get
		{
			float magnitude = this.mMagnitude;
			if (magnitude <= Math.[Friend]sMachineEpsilonFloat)
				return Plane.sZero;
			return Plane(this.mNormal / magnitude, this.mD / magnitude);
		}
	}

	public Plane mFlipped
	{
		[Inline] get => Plane(-this.mNormal, -this.mD);
	}

	static public float Dot(Plane plane, Vector4 value)
	{
		return plane.mNormal.mX * value.mX + plane.mNormal.mY * value.mY + plane.mNormal.mZ * value.mZ + plane.mD * value.mW;
	}

	static public float DotCoordinate(Plane plane, Vector3 point)
	{
		return Vector3.Dot(plane.mNormal, point) + plane.mD;
	}

	static public float DotNormal(Plane plane, Vector3 direction)
	{
		return Vector3.Dot(plane.mNormal, direction);
	}

	public float DistanceToPoint(Vector3 point)
	{
		float normalMagnitude = this.mMagnitude;
		if (normalMagnitude <= Math.[Friend]sMachineEpsilonFloat)
			return 0.0f;
		return (Vector3.Dot(this.mNormal, point) + this.mD) / normalMagnitude;
	}

	public bool GetSide(Vector3 point)
	{
		return Vector3.Dot(this.mNormal, point) + this.mD > 0.0f;
	}

	public bool TryIntersectRay(Ray ray, out float distance)
	{
		Plane plane = this.mNormalized;
		if (plane.mNormal.mMagnitudeSquared <= Math.[Friend]sMachineEpsilonFloat * Math.[Friend]sMachineEpsilonFloat)
		{
			distance = 0.0f;
			return false;
		}

		double denominator = (double)plane.mNormal.mX * ray.mDirection.mX + (double)plane.mNormal.mY * ray.mDirection.mY + (double)plane.mNormal.mZ * ray.mDirection.mZ;
		if (Math.Abs(denominator) <= (double)Math.[Friend]sMachineEpsilonFloat)
		{
			distance = 0.0f;
			return false;
		}

		double numerator = (double)plane.mNormal.mX * ray.mOrigin.mX + (double)plane.mNormal.mY * ray.mOrigin.mY + (double)plane.mNormal.mZ * ray.mOrigin.mZ + plane.mD;
		double hitDistance = -numerator / denominator;
		if (hitDistance < 0.0)
		{
			distance = 0.0f;
			return false;
		}
		distance = (float)hitDistance;
		return true;
	}

	public bool TryTransform(Matrix4x4 matrix, out Plane result)
	{
		Matrix4x4 inverse;
		if (!matrix.TryInvert(out inverse))
		{
			result = Plane.sZero;
			return false;
		}

		Vector3 transformedNormal = Vector3(
			inverse.m11 * this.mNormal.mX + inverse.m12 * this.mNormal.mY + inverse.m13 * this.mNormal.mZ + inverse.m14 * this.mD,
			inverse.m21 * this.mNormal.mX + inverse.m22 * this.mNormal.mY + inverse.m23 * this.mNormal.mZ + inverse.m24 * this.mD,
			inverse.m31 * this.mNormal.mX + inverse.m32 * this.mNormal.mY + inverse.m33 * this.mNormal.mZ + inverse.m34 * this.mD
		);
		float transformedD = inverse.m41 * this.mNormal.mX + inverse.m42 * this.mNormal.mY + inverse.m43 * this.mNormal.mZ + inverse.m44 * this.mD;
		float magnitude = transformedNormal.mMagnitude;
		if (magnitude <= Math.[Friend]sMachineEpsilonFloat)
		{
			result = Plane.sZero;
			return false;
		}
		result = Plane(transformedNormal / magnitude, transformedD / magnitude);
		return true;
	}

	static public bool operator ==(Plane lhs, Plane rhs)
	{
		return lhs.mNormal == rhs.mNormal && lhs.mD == rhs.mD;
	}

	static public bool operator !=(Plane lhs, Plane rhs)
	{
		return !(lhs == rhs);
	}
}
