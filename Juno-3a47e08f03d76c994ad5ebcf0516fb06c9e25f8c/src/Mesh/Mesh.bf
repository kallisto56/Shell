namespace Juno;

using System;
using System.Interop;

// Static (immutable) GPU geometry: vertex buffer + optional index buffer. Draw with Graphics.DrawMesh.
// The vertex format must match the input layout of the active ShaderProgram.
class Mesh
{
	public Buffer* mVertexBuffer;
	public Buffer* mIndexBuffer;
	public c_uint mVertexCount;
	public c_uint mIndexCount;
	public c_uint mStride;
	public PrimitiveTopology mTopology = .TriangleList;

	public ~this()
	{
		if (mVertexBuffer != null) Juno.DestroyBuffer(mVertexBuffer);
		if (mIndexBuffer != null) Juno.DestroyBuffer(mIndexBuffer);
	}

	static public Result<Mesh> Create(Device* device, void* vertices, int vertexCount, int stride, uint32* indices, int indexCount,
		PrimitiveTopology topology = .TriangleList)
	{
		let mesh = new Mesh();
		mesh.mVertexCount = (c_uint)vertexCount;
		mesh.mIndexCount = (c_uint)indexCount;
		mesh.mStride = (c_uint)stride;
		mesh.mTopology = topology;

		Buffer.CreateInfo info = default;
		info.mDevice = device;
		info.mUsage = .Immutable;
		info.mSize = (c_uint)(vertexCount * stride);
		info.mStride = (c_uint)stride;
		info.mBindFlags = .VertexBuffer;
		info.mInitialData = vertices;
		var result = Juno.CreateBuffer(&info, var vb);
		if (!JunoLog.Check(result, "CreateBuffer (mesh vertices)"))
		{
			delete mesh;
			return .Err;
		}
		mesh.mVertexBuffer = vb;

		if (indexCount > 0)
		{
			info = default;
			info.mDevice = device;
			info.mUsage = .Immutable;
			info.mSize = (c_uint)(indexCount * sizeof(uint32));
			info.mStride = (c_uint)sizeof(uint32);
			info.mBindFlags = .IndexBuffer;
			info.mInitialData = indices;
			result = Juno.CreateBuffer(&info, var ib);
			if (!JunoLog.Check(result, "CreateBuffer (mesh indices)"))
			{
				delete mesh;
				return .Err;
			}
			mesh.mIndexBuffer = ib;
		}
		return .Ok(mesh);
	}

	static public Result<Mesh> Create<T>(Device* device, Span<T> vertices, Span<uint32> indices = default,
		PrimitiveTopology topology = .TriangleList) where T : struct
	{
		return Create(device, vertices.Ptr, vertices.Length, sizeof(T), indices.Ptr, indices.Length, topology);
	}

	// Unit cube centered at the origin with per-face colors and 0..1 UVs per face.
	// Winding is clockwise when seen from outside (D3D default front face).
	static public Result<Mesh> CreateCube(Device* device, float size)
	{
		let h = size * 0.5f;
		// Face normal and up vector. Right = Up x Forward (Forward = -Normal), see Juno docs.
		float[6][6] faces = .(
			.(0, 0, -1, 0, 1, 0),   // front
			.(0, 0, 1, 0, 1, 0),    // back
			.(1, 0, 0, 0, 1, 0),    // right
			.(-1, 0, 0, 0, 1, 0),   // left
			.(0, 1, 0, 0, 0, 1),    // top
			.(0, -1, 0, 0, 0, -1)   // bottom
		);
		Color[6] colors = .(
			Color.cRed, Color.cGreen, Color.cBlue,
			Color.cYellow, Color.cCyan, Color.cMagenta
		);

		Vertex[24] vertices = default;
		uint32[36] indices = default;
		for (int f < 6)
		{
			let n = Vector3(faces[f][0], faces[f][1], faces[f][2]);
			let u = Vector3(faces[f][3], faces[f][4], faces[f][5]);
			// right = up x forward, forward = -normal
			let fwd = Vector3(-n.mX, -n.mY, -n.mZ);
			let r = Vector3(u.mY * fwd.mZ - u.mZ * fwd.mY, u.mZ * fwd.mX - u.mX * fwd.mZ, u.mX * fwd.mY - u.mY * fwd.mX);

			let cx = n.mX * h; let cy = n.mY * h; let cz = n.mZ * h;
			let v = f * 4;
			vertices[v + 0] = Vertex(cx + u.mX * h - r.mX * h, cy + u.mY * h - r.mY * h, cz + u.mZ * h - r.mZ * h, 0, 0, colors[f]); // TL
			vertices[v + 1] = Vertex(cx + u.mX * h + r.mX * h, cy + u.mY * h + r.mY * h, cz + u.mZ * h + r.mZ * h, 1, 0, colors[f]); // TR
			vertices[v + 2] = Vertex(cx - u.mX * h + r.mX * h, cy - u.mY * h + r.mY * h, cz - u.mZ * h + r.mZ * h, 1, 1, colors[f]); // BR
			vertices[v + 3] = Vertex(cx - u.mX * h - r.mX * h, cy - u.mY * h - r.mY * h, cz - u.mZ * h - r.mZ * h, 0, 1, colors[f]); // BL

			let i = f * 6;
			indices[i + 0] = (uint32)v; indices[i + 1] = (uint32)v + 1; indices[i + 2] = (uint32)v + 2;
			indices[i + 3] = (uint32)v; indices[i + 4] = (uint32)v + 2; indices[i + 5] = (uint32)v + 3;
		}
		return Create(device, &vertices[0], 24, sizeof(Vertex), &indices[0], 36);
	}
}
