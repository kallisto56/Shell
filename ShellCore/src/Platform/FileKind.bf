namespace Shell.Platform;

using System;

enum FileKind
{
	case File;
	case Directory;
	case Link;
	case Drive;
}
