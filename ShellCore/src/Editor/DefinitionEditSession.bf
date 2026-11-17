namespace Shell.Editor;

using System;
using Shell.Core;
using Shell.Composition;

// The definition being edited. Every command that changes it calls Touch(); the revision change is what propagates the edit to the live
// instances (UserWidgetHost compares revisions) and to editors observing the definition.
class DefinitionEditSession
{
	public CompositionDefinition mDefinition;       // not owned
	public DiagnosticSink mSink;
	public int mTouched;

	public this(CompositionDefinition definition, DiagnosticSink sink)
	{
		mDefinition = definition;
		mSink = sink;
	}

	public void Touch()
	{
		mDefinition.mRevision++;
		mTouched++;
	}
}
