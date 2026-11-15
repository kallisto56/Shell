namespace Juno;

using System;
using System.Interop;

enum SET_WINDOW_POS_FLAGS : uint32
{
	case SWP_NOSIZE = 0x0001;
	case SWP_NOMOVE = 0x0002;
	case SWP_NOZORDER = 0x0004;
	case SWP_NOREDRAW = 0x0008;
	case SWP_NOACTIVATE = 0x0010;
	case SWP_FRAMECHANGED = 0x0020;
	case SWP_SHOWWINDOW = 0x0040;
	case SWP_HIDEWINDOW = 0x0080;
}
