namespace Shell.Format;

using System;
using Shell.Core;

// State shared by the typed serializers of one load or save operation.
class SerializationContext
{
	public DiagnosticSink mSink;
	public StringPool mStrings;         // loading: the project's pool (model strings must outlive the Document)
	public Document mDocument;          // saving: where enum names are interned

	public this(DiagnosticSink sink, StringPool strings, Document document)
	{
		mSink = sink;
		mStrings = strings;
		mDocument = document;
	}
}
