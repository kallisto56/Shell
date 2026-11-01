namespace Shell.Platform;

using System;
using System.Collections;
using Shell.Core;

interface IMonitorService
{
	void GetMonitors(List<MonitorInfo> output);
	void SetListener(IMonitorListener listener);
	// Reserves an edge of a monitor (taskbar / dock). The real implementation registers an appbar.
	void ReserveWorkArea(uint32 monitor, RectF area);
	void ReleaseWorkArea(uint32 monitor);
}
