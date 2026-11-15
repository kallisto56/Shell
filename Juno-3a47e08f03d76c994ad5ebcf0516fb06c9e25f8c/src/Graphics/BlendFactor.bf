namespace Juno;

using System;
using System.Interop;

enum BlendFactor : c_int
{
	case Zero = 1;
	case One = 2;
	case SrcColor = 3;
	case InvSrcColor = 4;
	case SrcAlpha = 5;
	case InvSrcAlpha = 6;
	case DestAlpha = 7;
	case InvDestAlpha = 8;
	case DestColor = 9;
	case InvDestColor = 10;
	case SrcAlphaSat = 11;
	case Constant = 14;
	case InvConstant = 15;
}
