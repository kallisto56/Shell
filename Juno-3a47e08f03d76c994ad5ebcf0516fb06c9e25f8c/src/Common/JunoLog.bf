namespace Juno;

using System;
using System.Diagnostics;

static class JunoLog
{
	// Prints "<what> failed: <last Juno error message>" when `result` is not Ok. Returns true on success.
	static public bool Check(ErrorCode result, StringView what)
	{
		if (result == .Ok)
			return true;

		let message = StringView(Juno.GetLastErrorMessage());
		Console.WriteLine("[Juno] {} failed ({}): {}", what, result, message);
		Debug.WriteLine("[Juno] {} failed ({}): {}", what, result, message);
		return false;
	}
}
