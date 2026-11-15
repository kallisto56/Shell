namespace Juno;

using System;

[CRepr]
struct Ray
{
	public Vector3 mOrigin;
	public Vector3 mDirection;

	public this(Vector3 origin, Vector3 direction)
	{
		this.mOrigin = origin;
		this.mDirection = direction.mNormalized;
	}

	[Inline]
	public Vector3 GetPoint(float distance)
	{
		return this.mOrigin + this.mDirection * distance;
	}

	public bool TryIntersectPlane(Plane plane, out float distance)
	{
		return plane.TryIntersectRay(this, out distance);
	}

	public bool TryTransform(Matrix4x4 matrix, out Ray result)
	{
		Vector3 origin = Vector3.Transform(this.mOrigin, matrix);
		Vector3 direction = Vector3.TransformNormal(this.mDirection, matrix).mNormalized;
		if (direction.mMagnitudeSquared <= Math.[Friend]sMachineEpsilonFloat)
		{
			result = Ray(Vector3.sZero, Vector3.sZero);
			return false;
		}
		result = Ray(origin, direction);
		return true;
	}
}
