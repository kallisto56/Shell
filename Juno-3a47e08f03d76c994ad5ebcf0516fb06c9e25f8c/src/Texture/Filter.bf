namespace Juno;

using System;
using System.Interop;

enum Filter : c_int
{
	case MinMagMipPoint = 0x00;
	case MinMagPointMipLinear = 0x01;
	case MinPointMagLinearMipPoint = 0x04;
	case MinPointMagMipLinear = 0x05;
	case MinLinearMagMipPoint = 0x10;
	case MinLinearMagPointMipLinear = 0x11;
	case MinMagLinearMipPoint = 0x14;
	case MinMagMipLinear = 0x15;
	case Anisotropic = 0x55;
	case ComparisonMinMagMipPoint = 0x80;
	case ComparisonMinMagMipLinear = 0x95;
	case ComparisonAnisotropic = 0xD5;
}
