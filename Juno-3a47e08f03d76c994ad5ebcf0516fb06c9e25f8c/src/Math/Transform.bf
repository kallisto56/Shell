namespace Juno;

using System;

[CRepr]
struct Transform
{
	public Vector3 mPosition;
	public Quaternion mRotation;
	public Vector3 mScale;

	static public Transform sIdentity = Transform(Vector3.sZero, Quaternion.sIdentity, Vector3.sOne);

	public this(Vector3 position, Quaternion rotation, Vector3 scale)
	{
		this.mPosition = position;
		this.mRotation = rotation.mNormalized;
		this.mScale = scale;
	}

	public this(Vector3 position, Quaternion rotation)
	{
		this.mPosition = position;
		this.mRotation = rotation.mNormalized;
		this.mScale = Vector3.sOne;
	}

	public Vector3 mRight
	{
		[Inline] get => this.mRotation * Vector3.sRight;
	}

	public Vector3 mUp
	{
		[Inline] get => this.mRotation * Vector3.sUp;
	}

	public Vector3 mForward
	{
		[Inline] get => this.mRotation * Vector3.sForward;
	}

	public Matrix4x4 mLocalToWorldMatrix
	{
		[Inline] get => Matrix4x4(this.mScale, this.mRotation, this.mPosition);
	}

	public Matrix4x4 mWorldToLocalMatrix
	{
		[Inline] get
		{
			Matrix4x4 result;
			if (!this.mLocalToWorldMatrix.TryInvert(out result))
				return Matrix4x4.sZero;
			return result;
		}
	}

	public Vector3 TransformPoint(Vector3 point)
	{
		return Vector3.Transform(point, this.mLocalToWorldMatrix);
	}

	public Vector3 InverseTransformPoint(Vector3 point)
	{
		return Vector3.Transform(point, this.mWorldToLocalMatrix);
	}

	public Vector3 TransformDirection(Vector3 direction)
	{
		return this.mRotation * direction;
	}

	public Vector3 InverseTransformDirection(Vector3 direction)
	{
		return this.mRotation.mInverse * direction;
	}

	public Vector3 TransformVector(Vector3 vector)
	{
		return this.mRotation * (vector * this.mScale);
	}

	public Vector3 InverseTransformVector(Vector3 vector)
	{
		return (this.mRotation.mInverse * vector) / this.mScale;
	}

	public void SetPositionAndRotation(Vector3 position, Quaternion rotation) mut
	{
		this.mPosition = position;
		this.mRotation = rotation.mNormalized;
	}

	public void Translate(Vector3 translation) mut
	{
		this.mPosition = this.mPosition + translation;
	}

	public void Rotate(Quaternion rotation) mut
	{
		this.mRotation = (rotation * this.mRotation).mNormalized;
	}

	public void LookAt(Vector3 target, Vector3 up) mut
	{
		this.mRotation = Quaternion.LookRotation(target - this.mPosition, up);
	}
}
