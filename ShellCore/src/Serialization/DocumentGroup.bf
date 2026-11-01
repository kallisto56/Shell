namespace Shell.Serialization;

using System;
using System.Collections;
using Shell.Core;

// Named, ordered list of child nodes ("children", "layers", "bindings", "nodes", "links" ...).
class DocumentGroup
{
	public String mName = new .() ~ delete _;
	public List<DocumentNode> mNodes = new .() ~ DeleteContainerAndItems!(_);
}
