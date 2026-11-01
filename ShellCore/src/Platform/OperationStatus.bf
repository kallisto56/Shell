namespace Shell.Platform;

using System;

enum OperationStatus
{
	case Pending;       // started or waiting (also while a simulated delay is running)
	case Succeeded;
	case Cancelled;
	case Failed;
}
