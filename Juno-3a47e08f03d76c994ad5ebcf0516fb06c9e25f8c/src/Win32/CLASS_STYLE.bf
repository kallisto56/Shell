namespace Juno;

using System;
using System.Interop;

enum CLASS_STYLE : uint32
{
	case CS_VREDRAW = 0x0001;
	case CS_HREDRAW = 0x0002;
	case CS_DBLCLKS = 0x0008;
	case CS_OWNDC = 0x0020;
	case CS_CLASSDC = 0x0040;
	case CS_PARENTDC = 0x0080;
	case CS_NOCLOSE = 0x0200;
	case CS_SAVEBITS = 0x0800;
	case CS_BYTEALIGNCLIENT = 0x1000;
	case CS_BYTEALIGNWINDOW = 0x2000;
	case CS_GLOBALCLASS = 0x4000;
	case CS_IME = 0x00010000;
	case CS_DROPSHADOW = 0x00020000;
}
