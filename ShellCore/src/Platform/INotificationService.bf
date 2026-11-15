namespace Shell.Platform;

using System;

interface INotificationService
{
	void SetListener(INotificationListener listener);
	// Takes ownership of the notification.
	void Post(Notification notification);           // from the shell / user content (simulation: stays in the simulation)
}
