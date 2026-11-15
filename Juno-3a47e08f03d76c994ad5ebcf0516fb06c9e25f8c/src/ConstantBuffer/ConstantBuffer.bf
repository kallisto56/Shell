namespace Juno;

using System;
using System.Interop;

// Constant (uniform) buffer. Size is rounded up to a multiple of 16 bytes. Bind with Graphics.SetConstantBuffer.
class ConstantBuffer
{
	public Device* mDevice;
	public Buffer* mHandle;
	public c_uint mSize;

	public ~this()
	{
		if (mHandle != null)
			Juno.DestroyBuffer(mHandle);
	}

	static public Result<ConstantBuffer> Create(Device* device, int size)
	{
		Buffer.CreateInfo info = default;
		info.mDevice = device;
		info.mSize = (c_uint)((size + 15) & ~15);
		info.mUsage = .Default;
		info.mBindFlags = .ConstantBuffer;

		let result = Juno.CreateBuffer(&info, var handle);
		if (!JunoLog.Check(result, "CreateBuffer (constant)"))
			return .Err;

		let buffer = new ConstantBuffer();
		buffer.mDevice = device;
		buffer.mHandle = handle;
		buffer.mSize = info.mSize;
		return .Ok(buffer);
	}

	// `T` must be a [CRepr] struct whose size is a multiple of 16 bytes (pad it, HLSL cbuffers pack in 16-byte rows).
	public bool Update<T>(T data) where T : struct
	{
		var copy = data;
		return Update(&copy, sizeof(T));
	}

	public bool Update(void* data, int size)
	{
		Runtime.Assert(size == (int)mSize, "ConstantBuffer.Update: size must equal the buffer size (rounded up to 16 bytes)");
		let result = Juno.UpdateBuffer(mDevice, mHandle, 0, data, (c_size)size);
		return JunoLog.Check(result, "UpdateBuffer");
	}
}
