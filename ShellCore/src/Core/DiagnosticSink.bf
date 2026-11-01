namespace Shell.Core;

using System;
using System.Collections;

// Collects diagnostics. Nothing in the framework fails silently: every recoverable problem goes through a sink.
class DiagnosticSink
{
	public List<Diagnostic> mItems = new .() ~ DeleteContainerAndItems!(_);
	public int mErrorCount;
	public int mWarningCount;
	public IDiagnosticListener mListener;

	public void Report(Severity severity, StringView code, StringView message, StableId source = .sNone, StringView context = default)
	{
		let item = new Diagnostic();
		item.mSeverity = severity;
		item.mCode.Set(code);
		item.mMessage.Set(message);
		item.mSource = source;
		item.mContext.Set(context);
		mItems.Add(item);

		if (severity == .Error) mErrorCount++;
		else if (severity == .Warning) mWarningCount++;

		if (mListener != null)
			mListener.OnDiagnostic(item);
	}

	public void Error(StringView code, StringView message, StableId source = .sNone, StringView context = default)
	{
		Report(.Error, code, message, source, context);
	}

	public void Warning(StringView code, StringView message, StableId source = .sNone, StringView context = default)
	{
		Report(.Warning, code, message, source, context);
	}

	public bool mHasErrors => mErrorCount > 0;

	public void Clear()
	{
		mItems.ClearAndDeleteItems();
		mErrorCount = 0;
		mWarningCount = 0;
	}
}
