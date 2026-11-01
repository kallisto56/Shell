namespace Shell.Platform;

using System;

class OperationError
{
	public String mCode = new .() ~ delete _;       // "access-denied", "not-found", "in-use", "disk-full" ...
	public String mMessage = new .() ~ delete _;
}
