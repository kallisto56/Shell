namespace Shell.Platform;

using System;

interface IMonitorListener
{
	void OnMonitorsChanged();       // added, removed, resolution or DPI change
}
