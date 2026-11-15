namespace Shell.PlatformWin;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

class WinShellIntegration : IShellIntegration
{
	OperationLog mLog;

	public this(OperationLog log)
	{
		mLog = log;
	}

	static GUID Guid(uint32 a, uint16 b, uint16 c, uint8 d0, uint8 d1, uint8 d2, uint8 d3, uint8 d4, uint8 d5, uint8 d6, uint8 d7)
	{
		GUID guid = default;
		guid.Data1 = a;
		guid.Data2 = b;
		guid.Data3 = c;
		guid.Data4[0] = d0; guid.Data4[1] = d1; guid.Data4[2] = d2; guid.Data4[3] = d3;
		guid.Data4[4] = d4; guid.Data4[5] = d5; guid.Data4[6] = d6; guid.Data4[7] = d7;
		return guid;
	}

	// Caller owns the returned string. Null if the folder is unavailable.
	public String GetSpecialFolderPath(SpecialFolder folder)
	{
		GUID id;
		switch (folder)
		{
		case .Desktop: id = Guid(0xB4BFCC3A, 0xDB2C, 0x424C, 0xB0, 0x29, 0x7F, 0xE9, 0x9A, 0x87, 0xC6, 0x41);
		case .Documents: id = Guid(0xFDD39AD0, 0x238F, 0x46AF, 0xAD, 0xB4, 0x6C, 0x85, 0x48, 0x03, 0x69, 0xC7);
		case .Downloads: id = Guid(0x374DE290, 0x123F, 0x4565, 0x91, 0x64, 0x39, 0xC4, 0x92, 0x5E, 0x46, 0x7E);
		case .Pictures: id = Guid(0x33E28130, 0x4E1E, 0x4676, 0x83, 0x5A, 0x98, 0x39, 0x5C, 0x3B, 0xC3, 0xBB);
		case .Music: id = Guid(0x4BD8D571, 0x6D19, 0x48D3, 0xBE, 0x97, 0x42, 0x22, 0x20, 0x08, 0x0E, 0x43);
		case .Videos: id = Guid(0x18989B1D, 0x99B5, 0x455B, 0x84, 0x1C, 0xAB, 0x7C, 0x74, 0xE4, 0xDD, 0xFC);
		case .Home: id = Guid(0x5E6C858F, 0x0E22, 0x4760, 0x9A, 0xFE, 0xEA, 0x33, 0x17, 0xB6, 0x71, 0x73);
		case .RecycleBin: return new String("shell:RecycleBinFolder");
		case .Drives: return null;
		}

		char16* wide = null;
		if (NativeShell32.SHGetKnownFolderPath(&id, 0, null, &wide) != 0)
			return null;
		let result = new String();
		WideString.Decode(wide, result);
		NativeOle32.CoTaskMemFree(wide);
		return result;
	}

	IOperation Execute(StringView verb, StringView file, StringView arguments, uint32 mask, int32 show, StringView what)
	{
		let operation = mLog.Add(new ImmediateOperation());
		let wideVerb = scope List<char16>();
		let wideFile = scope List<char16>();
		let wideArguments = scope List<char16>();
		WideString.Encode(verb, wideVerb);
		WideString.Encode(file, wideFile);
		WideString.Encode(arguments, wideArguments);

		SHELLEXECUTEINFOW info = default;
		info.cbSize = (uint32)sizeof(SHELLEXECUTEINFOW);
		info.fMask = mask;
		info.lpVerb = wideVerb.Ptr;
		info.lpFile = wideFile.Ptr;
		info.lpParameters = arguments.IsEmpty ? null : wideArguments.Ptr;
		info.nShow = show;
		if (NativeShell32.ShellExecuteExW(&info) == 0)
			operation.Fail(WinErrors.FromLastError(NativeKernel32.GetLastError(), what));
		return operation;
	}

	public IOperation OpenPath(StringView path) => Execute("open", path, "", 0, 1, scope $"Opening '{path}'");

	// SEE_MASK_INVOKEIDLIST (0xC) is required for the "properties" verb.
	public IOperation ShowProperties(StringView path) => Execute("properties", path, "", 0xC, 1, scope $"Showing properties of '{path}'");

	public IOperation EmptyRecycleBin()
	{
		let operation = mLog.Add(new ImmediateOperation());
		// SHERB_NOCONFIRMATION | SHERB_NOPROGRESSUI | SHERB_NOSOUND
		let result = NativeShell32.SHEmptyRecycleBinW(null, null, 7);
		if (result != 0 && result != (int32)0x80070012)     // S_OK or "already empty"
			operation.Fail(WinErrors.Make("shell-error", scope $"Emptying the Recycle Bin failed (0x{result:X})."));
		return operation;
	}

	public IOperation Shutdown(bool restart)
	{
		// shutdown.exe takes care of privileges; the UI is expected to have asked for confirmation before calling this.
		return Execute("open", "shutdown.exe", restart ? "/r /t 0" : "/s /t 0", 0, 0, "Shutting down");
	}

	public IOperation Lock()
	{
		let operation = mLog.Add(new ImmediateOperation());
		if (NativeUser32.LockWorkStation() == 0)
			operation.Fail(WinErrors.FromLastError(NativeKernel32.GetLastError(), "Locking the workstation"));
		return operation;
	}

	public IOperation SignOut()
	{
		let operation = mLog.Add(new ImmediateOperation());
		if (NativeUser32.ExitWindowsEx(0, 0) == 0)      // EWX_LOGOFF
			operation.Fail(WinErrors.FromLastError(NativeKernel32.GetLastError(), "Signing out"));
		return operation;
	}
}
