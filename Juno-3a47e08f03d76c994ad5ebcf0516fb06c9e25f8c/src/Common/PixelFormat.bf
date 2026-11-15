namespace Juno;

using System;
using System.Interop;

enum PixelFormat : c_int
{
	case Unknown = 0;
	case R32G32B32A32_Float = 2;
	case R32G32B32A32_UInt = 3;
	case R32G32B32A32_SInt = 4;
	case R32G32B32_Float = 6;
	case R32G32B32_UInt = 7;
	case R32G32B32_SInt = 8;
	case R16G16B16A16_Float = 10;
	case R16G16B16A16_UNorm = 11;
	case R32G32_Float = 16;
	case R32G32_UInt = 17;
	case R32G32_SInt = 18;
	case R10G10B10A2_UNorm = 24;
	case R11G11B10_Float = 26;
	case R8G8B8A8_Typeless = 27;
	case R8G8B8A8_UNorm = 28;
	case R8G8B8A8_UNorm_SRGB = 29;
	case R8G8B8A8_UInt = 30;
	case R16G16_Float = 34;
	case R16G16_UNorm = 35;
	case R32_Typeless = 39;
	case D32_Float = 40;
	case R32_Float = 41;
	case R32_UInt = 42;
	case R32_SInt = 43;
	case R24G8_Typeless = 44;
	case D24_UNorm_S8_UInt = 45;
	case R8G8_UNorm = 49;
	case R16_Typeless = 53;
	case R16_Float = 54;
	case D16_UNorm = 55;
	case R16_UNorm = 56;
	case R16_UInt = 57;
	case R8_UNorm = 61;
	case R8_UInt = 62;
	case A8_UNorm = 65;
	case BC1_UNorm = 71;
	case BC1_UNorm_SRGB = 72;
	case BC3_UNorm = 77;
	case BC3_UNorm_SRGB = 78;
	case BC4_UNorm = 80;
	case BC5_UNorm = 83;
	case B8G8R8A8_UNorm = 87;
	case B8G8R8X8_UNorm = 88;
	case B8G8R8A8_UNorm_SRGB = 91;
	case BC7_UNorm = 98;
	case BC7_UNorm_SRGB = 99;
}
