namespace Shell.Platform;

using System;

interface INotificationListener
{
	void OnNotification(Notification notification);
}
