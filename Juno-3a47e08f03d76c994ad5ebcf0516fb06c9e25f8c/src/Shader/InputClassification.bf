namespace Juno;

using System;
using System.Interop;

enum InputClassification : c_int
{
	case PerVertexData = 0;
	case PerInstanceData = 1;
}
