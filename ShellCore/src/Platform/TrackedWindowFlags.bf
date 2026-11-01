namespace Shell.Platform;

using System;

enum TrackedWindowFlags : uint16
{
	case None = 0;
	case Visible = 1;
	case Minimized = 2;
	case Maximized = 4;
	case Active = 8;
	case ToolWindow = 16;       // not shown in a taskbar
	case Cloaked = 32;          // on another virtual desktop / suspended UWP
	case ShellOwned = 64;       // belongs to the custom shell itself (never listed as an application)
}
