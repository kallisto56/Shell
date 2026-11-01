namespace Shell.PlatformWin;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

class WinApplicationLauncher : IApplicationLauncher
{
	OperationLog mLog;

	public this(OperationLog log)
	{
		mLog = log;
	}

	public IOperation Launch(LaunchRequest request)
	{
		let operation = mLog.Add(new ImmediateOperation());
		let verb = scope List<char16>();
		let file = scope List<char16>();
		let arguments = scope List<char16>();
		let directory = scope List<char16>();
		WideString.Encode(request.bElevated ? "runas" : "open", verb);
		WideString.Encode(request.mTarget, file);
		WideString.Encode(request.mArguments, arguments);
		WideString.Encode(request.mWorkingDirectory, directory);

		SHELLEXECUTEINFOW info = default;
		info.cbSize = (uint32)sizeof(SHELLEXECUTEINFOW);
		info.lpVerb = verb.Ptr;
		info.lpFile = file.Ptr;
		info.lpParameters = request.mArguments.IsEmpty ? null : arguments.Ptr;
		info.lpDirectory = request.mWorkingDirectory.IsEmpty ? null : directory.Ptr;
		info.nShow = 1;     // SW_SHOWNORMAL
		if (NativeShell32.ShellExecuteExW(&info) == 0)
			operation.Fail(WinErrors.FromLastError(NativeKernel32.GetLastError(), scope $"Launching '{request.mTarget}'"));
		return operation;
	}

	void Scan(StringView folder, int depth, List<ApplicationEntry> output)
	{
		let found = scope List<FoundEntry>();
		if (WinFind.Enumerate(folder, found) != 0)
		{
			DeleteContainerAndItems!(found);
			return;
		}

		for (let item in found)
		{
			let full = scope String(folder);
			full.Append('\\');
			full.Append(item.mName);
			if (item.mIsDirectory)
			{
				if (depth < 4)
					Scan(full, depth + 1, output);
			}
			else if (item.mName.EndsWith(".lnk", .OrdinalIgnoreCase))
			{
				let entry = new ApplicationEntry();
				entry.mId.Set(full);
				entry.mDisplayName.Append(item.mName, 0, item.mName.Length - 4);
				entry.mTarget.Set(full);
				entry.mIconSource.Set(full);
				output.Add(entry);
			}
		}
		DeleteContainerAndItems!(found);
	}

	// Start menu shortcuts of all users and of the current user, sorted by name. Entries are owned by the caller's list.
	public void GetInstalledApplications(List<ApplicationEntry> output)
	{
		var vars = scope Dictionary<String, String>();
		Environment.GetEnvironmentVariables(vars);

		if (vars.TryGet("ProgramData", var key0, var programData))
			Scan(scope $"{programData}\\Microsoft\\Windows\\Start Menu\\Programs", 0, output);
		if (vars.TryGet("AppData", var key1, var appData))
			Scan(scope $"{appData}\\Microsoft\\Windows\\Start Menu\\Programs", 0, output);

		output.Sort(scope (a, b) => String.Compare(a.mDisplayName, b.mDisplayName, true));
	}
}
