namespace Shell.PlatformWin;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

// Windows offers no public API to intercept other applications' toast notifications, so this service is the shell's own
// notification center: notifications posted by shell content (and by future integrations such as a local notification
// listener) are delivered to the listener in-process. Takes ownership of posted notifications.
class WinNotificationService : INotificationService
{
	INotificationListener mListener;
	public List<Notification> mHistory = new .() ~ DeleteContainerAndItems!(_);

	public void SetListener(INotificationListener listener)
	{
		mListener = listener;
	}

	public void Post(Notification notification)
	{
		mHistory.Add(notification);
		if (mListener != null)
			mListener.OnNotification(notification);
	}
}
