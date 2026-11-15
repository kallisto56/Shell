namespace Shell.Platform;

using System;

// Permission bits a package (configuration, theme, third-party asset) can be granted. Downloaded content starts with
// None: it can render and compute, but cannot touch files, processes or windows until the user grants capabilities.
enum Capability : uint32
{
	case None = 0;
	case FileRead = 1;
	case FileWrite = 2;
	case FileDelete = 4;
	case LaunchProcess = 8;
	case WindowControl = 16;        // minimize / close / move windows of other applications
	case WindowObserve = 32;        // see the list of windows (titles reveal private information)
	case ShellIntegration = 64;     // open paths, recycle bin, system dialogs
	case Notifications = 128;
	case Clipboard = 256;
	case SystemSettings = 512;
	case Network = 1024;
}
