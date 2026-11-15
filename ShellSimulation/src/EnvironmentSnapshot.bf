namespace Shell.Simulation;

using System;

class EnvironmentSnapshot
{
	public VirtualFileSystem mFileSystem ~ delete _;
	public VirtualWindowManager mWindows ~ delete _;
	public double mClockSeconds;
}
