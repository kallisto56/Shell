# Juno Math

A compact Beef math library for game and desktop applications that render through DirectX.

## Files

- `Vector2.bf`, `Vector3.bf`, `Vector4.bf`
- `Quaternion.bf`
- `Matrix3x2.bf`, `Matrix3x3.bf`, `Matrix4x4.bf`
- `Plane.bf`, `Ray.bf`, `Transform.bf`
- `Example.bf`

All types are in `namespace Juno`. Add the `.bf` files to the Beef project that consumes them.

## Conventions

Matrices are stored in row-major field order and use the `System.Numerics` / DirectX row-vector convention. A position is transformed as `position * world * view * projection`; translation is stored in `m41`, `m42`, and `m43`. Matrix constructors list elements row by row. When uploading matrices to HLSL constant buffers, make the layout explicit: HLSL defaults to column-major packing, so either declare them `row_major` or transpose on the CPU to match the shader.


The 3D convention is left-handed, with `Vector3.sForward` pointing along +Z. Perspective and orthographic projection matrices use Direct3D depth range [0, 1]. `Vector3.Transform` matches `System.Numerics` and does not perform perspective division; use `Vector3.TransformCoordinate` when you need projected coordinates. Angles are in radians, including rotation constructors, quaternion factories, and `Vector2.Angle` / `Vector3.Angle`.

`Lerp` and quaternion interpolation clamp `t` to [0, 1], matching Unity's clamped interpolation behavior. Componentwise vector multiplication and division are provided; use `Vector2.Dot`, `Vector3.Dot`, or `Vector4.Dot` for dot products.

The `mInverse` getter returns the zero matrix when inversion fails. Matrix `TryInvert` methods reject a zero determinant. Prefer `TryInvert(out result)` when singularity must be handled explicitly. `Quaternion.mInverse` falls back to identity for a zero-length quaternion, while `TryInvert` reports failure. Normalizing a zero vector returns zero; normalizing a zero quaternion returns identity.

`Ray` normalizes its direction at construction, so distances returned by ray-plane intersections are measured in world-distance units for an unscaled ray.

## Example

`Example.bf` demonstrates object, view, and projection transforms. It is illustrative source; the library has not been compiled in this environment.
