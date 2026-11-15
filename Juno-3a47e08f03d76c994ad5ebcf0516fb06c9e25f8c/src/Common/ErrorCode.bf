namespace Juno;

using System;
using System.Interop;

enum ErrorCode : c_int
{
	case Ok = 0;
	case InvalidArgument;
	case OutOfMemory;
	case DeviceCreationFailed;
	case DeviceLost;
	case SwapChainCreationFailed;
	case SwapChainResizeFailed;
	case PresentFailed;
	case BufferCreationFailed;
	case TextureCreationFailed;
	case StateCreationFailed;
	case ShaderCompileFailed;
	case ShaderCreationFailed;
	case InputLayoutCreationFailed;
	case FenceCreationFailed;
	case MapFailed;
	case FileNotFound;
	case Unsupported;
	case ImageLoadFailed;
	case Unknown;
}
