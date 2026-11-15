namespace Shell.Serialization;

using System;
using System.Collections;
using Shell.Core;

// Generic parsed form of the saved format: typed node + stable id + ordered fields + ordered groups of children.
// The text parser produces it, typed model classes are built from it (IDocumentSerializable), and migrations rewrite it
// *before* typed loading so old files never need old model code.
class DocumentNode
{
	public String mType = new .() ~ delete _;
	public StableId mId;
	public List<DocumentField> mFields = new .() ~ DeleteContainerAndItems!(_);
	public List<DocumentGroup> mGroups = new .() ~ DeleteContainerAndItems!(_);

	public DocumentField FindField(StringView name)
	{
		for (let field in mFields)
		{
			if (field.mName == name)
				return field;
		}
		return null;
	}

	public DocumentGroup FindGroup(StringView name)
	{
		for (let group in mGroups)
		{
			if (group.mName == name)
				return group;
		}
		return null;
	}
}
