namespace Shell.Simulation;

using System;

enum VfsError
{
	case None;
	case NotFound;
	case AlreadyExists;
	case AccessDenied;
	case InvalidName;
	case InvalidDestination;    // destination is not a folder, or is inside the source
}
