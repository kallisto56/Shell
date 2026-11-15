namespace Juno;

using System;
using System.Interop;

enum LAYERED_WINDOW_ATTRIBUTES : uint32
{
	case LWA_COLORKEY = 0x00000001;
	case LWA_ALPHA = 0x00000002;
}
