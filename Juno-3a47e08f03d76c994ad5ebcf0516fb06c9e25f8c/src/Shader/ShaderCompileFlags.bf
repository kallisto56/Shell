namespace Juno;

using System;
using System.Interop;

enum ShaderCompileFlags : c_uint
{
	case None = 0;
	case Debug = 0x1;
	case SkipValidation = 0x2;
	case SkipOptimization = 0x4;
	case PackMatrixRowMajor = 0x8;
	case PackMatrixColumnMajor = 0x10;
	case EnableStrictness = 0x800;
	case OptimizationLevel0 = 0x4000;
	case OptimizationLevel3 = 0x8000;
	case WarningsAreErrors = 0x40000;
}
