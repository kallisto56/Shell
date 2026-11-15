namespace Juno;

using System;

// Adapted from the SDL3 PushBuffer: wraps a mapped dynamic Juno buffer and appends vertices / colors /
// indices to it. Map() before pushing, Unmap() before the buffer is used by a draw call.
// mIndex is the element cursor and survives Unmap/Map, so appending can continue (WriteNoOverwrite).
struct PushBuffer
{
	public Device* mDevice;
	public Buffer* mBuffer;
	public bool bIsMapped;
	public bool bIsValid => this.bIsMapped && this.uPtr != null;

	public uint32 mIndex;
	public uint32 mCapacity;

	public Span<uint32> mUInt32 => Span<uint32>(this.uUInt32, (int)this.mCapacity);
	public Span<Vertex> mVertexes => Span<Vertex>(this.uVertex, (int)this.mCapacity);
	public Span<Color> mColors => Span<Color>(this.uColor, (int)this.mCapacity);

	[Union]
	public struct UnionStruct
	{
		public void* uPtr;
		public Vertex* uVertex;
		public Color* uColor;
		public uint8* uUInt8;
		public uint16* uUInt16;
		public uint32* uUInt32;
	};

	public using UnionStruct mPtr;


	// capacity = number of elements the buffer can hold (vertices or indices).
	public this(Device* device, Buffer* buffer, uint32 capacity)
	{
		this.mDevice = device;
		this.mBuffer = buffer;
		this.bIsMapped = false;
		this.mIndex = 0;
		this.mCapacity = capacity;
		this.mPtr = default;
	}


	// Maps the buffer. Use .WriteDiscard for the first map of a frame / after a reset,
	// .WriteNoOverwrite to keep appending after already-submitted data.
	public bool Map(MapMode mode) mut
	{
		if (this.bIsMapped)
			return true;

		let result = Juno.MapBuffer(this.mDevice, this.mBuffer, mode, var ptr);
		if (result != .Ok)
		{
			this.uPtr = null;
			return false;
		}
		this.uPtr = ptr;
		this.bIsMapped = true;
		return true;
	}


	public void Unmap() mut
	{
		if (!this.bIsMapped)
			return;
		Juno.UnmapBuffer(this.mDevice, this.mBuffer);
		this.uPtr = null;
		this.bIsMapped = false;
	}


	public void Reset() mut
	{
		this.mIndex = 0;
	}


	public uint32 Push(Vertex v) mut
	{
		var idx = this.mIndex;
		this.uVertex[this.mIndex++] = v;
		return idx;
	}


	public uint32 Push(Vertex a, Vertex b, Vertex c) mut
	{
		var idx = this.mIndex;
		this.uVertex[this.mIndex++] = a;
		this.uVertex[this.mIndex++] = b;
		this.uVertex[this.mIndex++] = c;
		return idx;
	}


	public uint32 Push(Vertex a, Vertex b, Vertex c, Vertex d) mut
	{
		var idx = this.mIndex;
		this.uVertex[this.mIndex++] = a;
		this.uVertex[this.mIndex++] = b;
		this.uVertex[this.mIndex++] = c;
		this.uVertex[this.mIndex++] = d;
		return idx;
	}


	public void Push(Span<Vertex> vertices) mut
	{
		for (var n < vertices.Length)
			this.uVertex[this.mIndex++] = vertices[n];
	}


	public void Push(Color color) mut
	{
		this.uColor[this.mIndex++] = color;
	}


	public void Push(Span<Color> colors) mut
	{
		for (var n < colors.Length)
			this.uColor[this.mIndex++] = colors[n];
	}


	public void PushColors(params Color[] colors) mut
	{
		for (var n = 0; n < colors.Count; n++)
			this.uColor[this.mIndex++] = colors[n];
	}


	public void PushUInt32(uint32 a, uint32 b, uint32 c) mut
	{
		this.uUInt32[this.mIndex++] = a;
		this.uUInt32[this.mIndex++] = b;
		this.uUInt32[this.mIndex++] = c;
	}


	public void PushUInt32(uint32 a, uint32 b, uint32 c, uint32 d, uint32 e, uint32 f) mut
	{
		this.uUInt32[this.mIndex++] = a;
		this.uUInt32[this.mIndex++] = b;
		this.uUInt32[this.mIndex++] = c;
		this.uUInt32[this.mIndex++] = d;
		this.uUInt32[this.mIndex++] = e;
		this.uUInt32[this.mIndex++] = f;
	}


	public void PushUInt32(uint32 u32) mut
	{
		this.uUInt32[this.mIndex++] = u32;
	}


	public void PushUInt32s(params uint32[] u32) mut
	{
		for (var n = 0; n < u32.Count; n++)
			this.uUInt32[this.mIndex++] = u32[n];
	}


	public bool CanFit(int count)
	{
		return ((int)this.mIndex + count <= (int)this.mCapacity);
	}
}
