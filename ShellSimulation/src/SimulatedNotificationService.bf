namespace Shell.Simulation;

using System;
using System.Collections;
using Shell.Platform;

// Notifications posted by simulated applications / user content. They stay inside the simulation.
class SimulatedNotificationService : INotificationService
{
	INotificationListener mListener;
	public List<Notification> mHistory = new .() ~ DeleteContainerAndItems!(_);

	public void SetListener(INotificationListener listener)
	{
		mListener = listener;
	}

	// Takes ownership of the notification.
	public void Post(Notification notification)
	{
		mHistory.Add(notification);
		if (mListener != null)
			mListener.OnNotification(notification);
	}
}
