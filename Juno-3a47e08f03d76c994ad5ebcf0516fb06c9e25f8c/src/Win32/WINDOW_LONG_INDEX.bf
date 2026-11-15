namespace Juno;

using System;
using System.Interop;

enum WINDOW_LONG_INDEX : int32
{
	case GWL_EXSTYLE = -20;
	case GWL_STYLE = -16;
	case GWLP_USERDATA = -21;
	case GWLP_WNDPROC = -4;
}
