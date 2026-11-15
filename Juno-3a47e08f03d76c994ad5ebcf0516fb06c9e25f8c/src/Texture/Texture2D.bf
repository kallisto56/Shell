namespace Juno;

using System;
using System.Collections;
using System.IO;
using System.Interop;

// Managed wrapper around a Juno Texture (2D). Deleting the object destroys the GPU texture.
class Texture2D
{
	public Device* mDevice;
	public Texture* mHandle;
	public int32 mWidth;
	public int32 mHeight;
	public PixelFormat mFormat;
	bool bOwnsHandle = true;

	public ~this()
	{
		if (bOwnsHandle && mHandle != null)
			Juno.DestroyTexture(mHandle);
	}

	// Wraps a texture owned by somebody else (e.g. the swap chain back buffer). Not destroyed on delete.
	static public Texture2D Wrap(Device* device, Texture* handle)
	{
		let texture = new Texture2D();
		texture.mDevice = device;
		texture.mHandle = handle;
		texture.bOwnsHandle = false;
		var w = c_uint(0);
		var h = c_uint(0);
		Juno.GetTextureSize(handle, &w, &h);
		texture.mWidth = (int32)w;
		texture.mHeight = (int32)h;
		return texture;
	}

	// pixels may be null (uninitialized contents). rowPitch is in bytes.
	static public Result<Texture2D> Create(Device* device, int width, int height, PixelFormat format, void* pixels = null, int rowPitch = 0,
		bool generateMips = false, BindFlags bindFlags = .ShaderResource)
	{
		Texture.CreateInfo info = .();
		info.mDevice = device;
		info.mWidth = (c_uint)width;
		info.mHeight = (c_uint)height;
		info.mMipLevels = generateMips ? 0 : 1;
		info.bGenerateMips = generateMips;
		info.mFormat = format;
		info.mBindFlags = bindFlags;
		info.mInitialData = pixels;
		info.mRowPitch = (c_uint)rowPitch;

		let result = Juno.CreateTexture(&info, var handle);
		if (!JunoLog.Check(result, "CreateTexture"))
			return .Err;

		let texture = new Texture2D();
		texture.mDevice = device;
		texture.mHandle = handle;
		texture.mWidth = (int32)width;
		texture.mHeight = (int32)height;
		texture.mFormat = format;
		return .Ok(texture);
	}

	static public Result<Texture2D> FromRGBA(Device* device, int width, int height, uint8* rgba, bool generateMips = true)
	{
		return Create(device, width, height, .R8G8B8A8_UNorm, rgba, width * 4, generateMips);
	}

	// Loads a PNG file via stb_image.
	static public Result<Texture2D> FromFile(Device* device, StringView path, bool generateMips = true, bool srgb = false)
	{
		let bytes = scope List<uint8>();
		if (File.ReadAll(path, bytes) case .Err)
		{
			Console.WriteLine("[Juno] Could not read image file '{}'", path);
			return .Err;
		}

		let format = srgb ? PixelFormat.R8G8B8A8_UNorm_SRGB : PixelFormat.R8G8B8A8_UNorm;
		var result = Juno.LoadImage(bytes.Ptr, (c_size)bytes.Count, format, var image);
		if (!JunoLog.Check(result, "LoadImage"))
			return .Err;

		let width = (int32)image.mWidth;
		let height = (int32)image.mHeight;
		result = Juno.CreateTextureFromImage(device, image, generateMips, var handle);
		Juno.DestroyImage(image);
		if (!JunoLog.Check(result, "CreateTextureFromImage"))
			return .Err;

		let texture = new Texture2D();
		texture.mDevice = device;
		texture.mHandle = handle;
		texture.mWidth = width;
		texture.mHeight = height;
		texture.mFormat = format;
		return .Ok(texture);
	}

	// Uploads pixels into mip 0. region == null replaces the whole texture.
	public bool Update(Region* region, void* data, int rowPitch)
	{
		let result = Juno.UpdateTexture(mDevice, mHandle, 0, 0, region, data, (c_uint)rowPitch);
		return JunoLog.Check(result, "UpdateTexture");
	}
}
