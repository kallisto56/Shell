namespace Shell.Editor;

using System;
using System.Collections;

// What "extract UserWidget" found. Errors block the extraction (nothing is changed); warnings are informational.
class ExtractionReport
{
	public List<String> mErrors = new .() ~ DeleteContainerAndItems!(_);
	public List<String> mWarnings = new .() ~ DeleteContainerAndItems!(_);
	public int mExposedCount;           // members published on the new definition because outside objects used them
	public int mRewrittenBindings;      // outside bindings redirected to the new instance

	public bool mIsOk => mErrors.Count == 0;
}
