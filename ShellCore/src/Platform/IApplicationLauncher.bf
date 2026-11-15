namespace Shell.Platform;

using System;
using System.Collections;

interface IApplicationLauncher
{
	IOperation Launch(LaunchRequest request);
	void GetInstalledApplications(List<ApplicationEntry> output);
}
