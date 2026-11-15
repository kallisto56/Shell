namespace Shell.Simulation;

using System;

enum FileOperationKind
{
	case CreateFolder;
	case Rename;
	case Move;
	case Copy;
	case Delete;
}
