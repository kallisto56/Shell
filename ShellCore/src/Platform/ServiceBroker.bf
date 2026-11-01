namespace Shell.Platform;

using System;
using Shell.Core;

// The only way content (Blueprints, widgets, UserWidgets of a package) reaches platform services. Each call states the
// package it runs for; the broker checks the package's capabilities before returning the service and reports a diagnostic
// when access is denied. Content therefore never holds a raw service pointer.
class ServiceBroker
{
	PlatformServices mServices;
	PermissionSet mPermissions;
	DiagnosticSink mDiagnostics;

	public this(PlatformServices services, PermissionSet permissions, DiagnosticSink diagnostics)
	{
		mServices = services;
		mPermissions = permissions;
		mDiagnostics = diagnostics;
	}

	bool Check(StableId package, Capability capability, StringView service)
	{
		if (mPermissions.IsGranted(package, capability))
			return true;
		mDiagnostics.Error("PLT0001", scope $"Package {package} is not allowed to use {service} (missing capability {capability}).", package);
		return false;
	}

	public IFileSystemService GetFiles(StableId package, Capability access)
	{
		return Check(package, access, "the file system") ? mServices.mFiles : null;
	}

	public IApplicationLauncher GetLauncher(StableId package)
	{
		return Check(package, .LaunchProcess, "process launching") ? mServices.mLauncher : null;
	}

	public IWindowTracker GetWindows(StableId package, bool control)
	{
		return Check(package, control ? .WindowControl : .WindowObserve, "window tracking") ? mServices.mWindows : null;
	}

	public IShellIntegration GetShell(StableId package)
	{
		return Check(package, .ShellIntegration, "shell integration") ? mServices.mShell : null;
	}

	public INotificationService GetNotifications(StableId package)
	{
		return Check(package, .Notifications, "notifications") ? mServices.mNotifications : null;
	}

	public IClipboardService GetClipboard(StableId package)
	{
		return Check(package, .Clipboard, "the clipboard") ? mServices.mClipboard : null;
	}

	// Monitors, clock and text input are not sensitive: always available to rendering and widgets.
	public IMonitorService GetMonitors() => mServices.mMonitors;
	public IClock GetClock() => mServices.mClock;
	public ITextInputService GetTextInput() => mServices.mTextInput;
}
