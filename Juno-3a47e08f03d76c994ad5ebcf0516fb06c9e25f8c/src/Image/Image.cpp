#include "pch.h"
#include "JunoInternal.h"

// Only the PNG decoder is compiled in, and file I/O is not needed: Beef hands us the bytes.
#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_PNG
#define STBI_NO_STDIO
#include "./../Thirdparty\stb_image.h"

// Maps the requested format (or the source channel count for Unknown) to the stb channel count + final format.
static JunoErrorCode ResolveFormat(JunoPixelFormat desired, int sourceChannels, int* pChannels, JunoPixelFormat* pFormat)
{
	switch (desired)
	{
	case JunoPixelFormat_Unknown:
		if (sourceChannels == 1)
		{
			*pChannels = 1;
			*pFormat = JunoPixelFormat_R8_UNorm;
		}
		else if (sourceChannels == 2)
		{
			*pChannels = 2;
			*pFormat = JunoPixelFormat_R8G8_UNorm;
		}
		else
		{
			*pChannels = 4;
			*pFormat = JunoPixelFormat_R8G8B8A8_UNorm;
		}
		return JunoErrorCode_Ok;

	case JunoPixelFormat_R8_UNorm:
		*pChannels = 1;
		*pFormat = desired;
		return JunoErrorCode_Ok;

	case JunoPixelFormat_R8G8_UNorm:
		*pChannels = 2;
		*pFormat = desired;
		return JunoErrorCode_Ok;

	case JunoPixelFormat_R8G8B8A8_UNorm:
	case JunoPixelFormat_R8G8B8A8_UNorm_SRGB:
		*pChannels = 4;
		*pFormat = desired;
		return JunoErrorCode_Ok;

	default:
		return JunoSetError(JunoErrorCode_Unsupported, S_OK, "Unsupported image format %d. Use Unknown, R8_UNorm, R8G8_UNorm, R8G8B8A8_UNorm or R8G8B8A8_UNorm_SRGB.", (int)desired);
	}
}

JUNO_API JunoErrorCode JunoLoadImage(const void* pData, c_size size, JunoPixelFormat desiredFormat, JunoImage** ppImage)
{
	JUNO_ASSERT(pData != nullptr);
	JUNO_ASSERT(size > 0 && size <= (c_size)INT_MAX);
	JUNO_ASSERT(ppImage != nullptr);
	*ppImage = nullptr;

	const stbi_uc* pBytes = (const stbi_uc*)pData;

	// Header only: detects the source channel count (a PNG may be grey, grey+alpha, RGB or RGBA).
	int width = 0, height = 0, sourceChannels = 0;
	if (!stbi_info_from_memory(pBytes, size, &width, &height, &sourceChannels))
		return JunoSetError(JunoErrorCode_ImageLoadFailed, S_OK, "Not a valid PNG image: %s", stbi_failure_reason());

	int channels = 0;
	JunoPixelFormat format = JunoPixelFormat_Unknown;
	JunoErrorCode code = ResolveFormat(desiredFormat, sourceChannels, &channels, &format);
	if (code != JunoErrorCode_Ok)
		return code;

	// stb converts to `channels` while decoding (grey <-> RGB, adds opaque alpha, 16-bit -> 8-bit).
	int actualChannels = 0;
	stbi_uc* pPixels = stbi_load_from_memory(pBytes, size, &width, &height, &actualChannels, channels);
	if (pPixels == nullptr)
		return JunoSetError(JunoErrorCode_ImageLoadFailed, S_OK, "PNG decoding failed: %s", stbi_failure_reason());

	JunoImage* pImage = new (std::nothrow) JunoImage();
	if (pImage == nullptr)
	{
		stbi_image_free(pPixels);
		return JunoSetError(JunoErrorCode_OutOfMemory, S_OK, "Out of memory");
	}

	pImage->mPixels = pPixels;
	pImage->mWidth = (c_uint)width;
	pImage->mHeight = (c_uint)height;
	pImage->mChannels = (c_uint)channels;
	pImage->mRowPitch = (c_uint)(width * channels);
	pImage->mFormat = format;

	*ppImage = pImage;
	return JunoErrorCode_Ok;
}

JUNO_API void JunoDestroyImage(JunoImage* pImage)
{
	if (pImage == nullptr)
		return;
	stbi_image_free(pImage->mPixels);
	delete pImage;
}