namespace Juno;

using System;
using System.Interop;

enum SHOW_WINDOW_COMMAND : int32
{
	case SW_HIDE = 0;
	case SW_SHOWNORMAL = 1;
	case SW_SHOWMINIMIZED = 2;
	case SW_SHOWMAXIMIZED = 3;
	case SW_SHOWNOACTIVATE = 4;
	case SW_SHOW = 5;
	case SW_MINIMIZE = 6;
	case SW_SHOWMINNOACTIVE = 7;
	case SW_SHOWNA = 8;
	case SW_RESTORE = 9;
	case SW_SHOWDEFAULT = 10;
}
