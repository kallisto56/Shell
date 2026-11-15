namespace Juno;

using System;
using System.Interop;

enum ShaderStage : c_int
{
	case Vertex = 0;
	case Pixel = 1;
	case Geometry = 2;
	case Compute = 3;
}
