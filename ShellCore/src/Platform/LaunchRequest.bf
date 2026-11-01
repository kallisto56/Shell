namespace Shell.Platform;

using System;

class LaunchRequest
{
	public String mTarget = new .() ~ delete _;         // path, URI or application id
	public String mArguments = new .() ~ delete _;
	public String mWorkingDirectory = new .() ~ delete _;
	public bool bElevated;                              // requires an additional capability prompt in the real shell
}
