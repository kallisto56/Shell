namespace Shell.Core;

using System;

// One message of the error-reporting pipeline (load, validation, Blueprint execution, simulation ...).
// Codes are stable strings ("BP0003", "SER0101") so the editor can link to documentation and filter.
class Diagnostic
{
	public Severity mSeverity;
	public String mCode = new .() ~ delete _;
	public String mMessage = new .() ~ delete _;
	public StableId mSource;                    // object the message is about (may be none)
	public String mContext = new .() ~ delete _;  // free-form location, e.g. "Taskbar/Clock/Text"
}
