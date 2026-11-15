/*namespace Juno;

using System;

struct MathExample
{
	static public void Run()
	{
		Vector3 localPoint = Vector3(1.0f, 0.0f, 0.0f);
		Quaternion rotation = Quaternion.FromAxisAngle(Vector3.sUp, Math.PI_f * 0.5f);
		Transform objectTransform = Transform(Vector3(3.0f, 0.0f, 5.0f), rotation, Vector3.sOne);
		Matrix4x4 view = Matrix4x4.CreateLookAt(
			Vector3(0.0f, 2.0f, -5.0f),
			Vector3(0.0f, 0.0f, 0.0f),
			Vector3.sUp
		);
		Matrix4x4 projection = Matrix4x4.CreatePerspectiveFieldOfView(
			Math.PI_f / 3.0f,
			16.0f / 9.0f,
			0.1f,
			1000.0f
		);
		Matrix4x4 worldViewProjection = objectTransform.mLocalToWorldMatrix * view * projection;
		Vector3 projectedPoint = Vector3.TransformCoordinate(localPoint, worldViewProjection);

		Plane ground = Plane(Vector3.sUp, 0.0f);
		Ray ray = Ray(Vector3(0.0f, 2.0f, 0.0f), Vector3(0.0f, -1.0f, 0.0f));
		float distance;
		bool hitGround = ray.TryIntersectPlane(ground, out distance);
	}
}*/
