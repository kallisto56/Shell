namespace Shell.Serialization;

using System;
using Shell.Core;

class Document
{
	public SchemaVersion mVersion;
	public StringPool mStrings = new .() ~ delete _;
	public DocumentNode mRoot ~ delete _;
}
