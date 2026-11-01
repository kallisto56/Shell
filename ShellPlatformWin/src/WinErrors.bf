namespace Shell.PlatformWin;

using System;
using Shell.Platform;

static class WinErrors
{
	static public OperationError FromLastError(uint32 code, StringView what)
	{
		let error = new OperationError();
		switch (code)
		{
		case 2, 3: error.mCode.Set("not-found");
		case 5: error.mCode.Set("access-denied");
		case 32, 33: error.mCode.Set("in-use");
		case 80, 183: error.mCode.Set("already-exists");
		case 112: error.mCode.Set("disk-full");
		case 123, 161: error.mCode.Set("invalid-name");
		default: error.mCode.AppendF("error-{}", code);
		}
		error.mMessage.AppendF("{} failed (Windows error {}).", what, code);
		return error;
	}

	static public OperationError Make(StringView code, StringView message)
	{
		let error = new OperationError();
		error.mCode.Set(code);
		error.mMessage.Set(message);
		return error;
	}
}
