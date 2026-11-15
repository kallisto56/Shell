namespace Juno;

using System;
using System.Interop;

enum PEEK_MESSAGE_FLAGS : uint32
{
	case PM_NOREMOVE = 0x0000;
	case PM_REMOVE = 0x0001;
	case PM_NOYIELD = 0x0002;
}
