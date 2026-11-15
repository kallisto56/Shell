namespace Juno;

using System;
using System.Interop;

enum DWM_SYSTEMBACKDROP_TYPE : int32
{
	case DWMSBT_AUTO = 0;
	case DWMSBT_NONE = 1;
	case DWMSBT_MAINWINDOW = 2;
	case DWMSBT_TRANSIENTWINDOW = 3;
	case DWMSBT_TABBEDWINDOW = 4;
}
