namespace Shell.Simulation;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

class VirtualMonitorService : IMonitorService
{
	List<MonitorInfo> mMonitors = new .() ~ DeleteContainerAndItems!(_);
	List<RectF> mBaseWorkAreas = new .() ~ delete _;
	IMonitorListener mListener;

	// Replaces the monitor layout (resolution / DPI / hot-plug scenarios). Notifies the listener.
	public void AddMonitor(StringView name, RectF bounds, float dpiScale, bool primary)
	{
		let monitor = new MonitorInfo();
		monitor.mId = (uint32)(mMonitors.Count + 1);
		monitor.mName.Set(name);
		monitor.mBounds = bounds;
		monitor.mWorkArea = bounds;
		monitor.mDpiScale = dpiScale;
		monitor.bPrimary = primary;
		mMonitors.Add(monitor);
		mBaseWorkAreas.Add(bounds);
		Notify();
	}

	public void Clear()
	{
		mMonitors.ClearAndDeleteItems();
		mBaseWorkAreas.Clear();
		Notify();
	}

	public void SetDpiScale(uint32 monitor, float dpiScale)
	{
		for (let m in mMonitors)
		{
			if (m.mId == monitor)
				m.mDpiScale = dpiScale;
		}
		Notify();
	}

	void Notify()
	{
		if (mListener != null)
			mListener.OnMonitorsChanged();
	}

	public void GetMonitors(List<MonitorInfo> output) => output.AddRange(mMonitors);
	public void SetListener(IMonitorListener listener) { mListener = listener; }

	public void ReserveWorkArea(uint32 monitor, RectF area)
	{
		for (int i < mMonitors.Count)
		{
			if (mMonitors[i].mId != monitor)
				continue;
			// Remove the reserved strip from the nearest edge it touches.
			let work = mBaseWorkAreas[i];
			if (area.mWidth >= area.mHeight)
			{
				if (area.mY <= work.mY + 1) mMonitors[i].mWorkArea = RectF(work.mX, work.mY + area.mHeight, work.mWidth, work.mHeight - area.mHeight);
				else mMonitors[i].mWorkArea = RectF(work.mX, work.mY, work.mWidth, work.mHeight - area.mHeight);
			}
			else
			{
				if (area.mX <= work.mX + 1) mMonitors[i].mWorkArea = RectF(work.mX + area.mWidth, work.mY, work.mWidth - area.mWidth, work.mHeight);
				else mMonitors[i].mWorkArea = RectF(work.mX, work.mY, work.mWidth - area.mWidth, work.mHeight);
			}
		}
		Notify();
	}

	public void ReleaseWorkArea(uint32 monitor)
	{
		for (int i < mMonitors.Count)
		{
			if (mMonitors[i].mId == monitor)
				mMonitors[i].mWorkArea = mBaseWorkAreas[i];
		}
		Notify();
	}
}
