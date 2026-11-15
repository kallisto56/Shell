namespace Juno;

using System;
using System.Interop;

enum DWM_WINDOW_CORNER_PREFERENCE : int32
{
	case DWMWCP_DEFAULT = 0;
	case DWMWCP_DONOTROUND = 1;
	case DWMWCP_ROUND = 2;
	case DWMWCP_ROUNDSMALL = 3;
}
