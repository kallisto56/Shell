namespace Juno;

using System;
using System.Interop;

enum PrimitiveTopology : c_int
{
	case PointList = 1;
	case LineList = 2;
	case LineStrip = 3;
	case TriangleList = 4;
	case TriangleStrip = 5;
}
