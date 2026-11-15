namespace Juno;

using System;
using System.Interop;

enum IMAGE_TYPE : uint32
{
	case IMAGE_BITMAP = 0;
	case IMAGE_ICON = 1;
	case IMAGE_CURSOR = 2;
}
