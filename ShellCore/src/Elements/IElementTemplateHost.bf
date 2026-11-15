namespace Shell.Elements;

using System;

// Creates / destroys the content of template elements (ElementNodeData.mExistsWhen). Implemented by the element instantiator of
// the runtime; the binding system calls it (deferred to the Commit phase) when an "exists" condition changes.
interface IElementTemplateHost
{
	void SetExists(Element element, bool exists);
}
