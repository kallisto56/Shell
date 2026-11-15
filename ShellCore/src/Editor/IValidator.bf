namespace Shell.Editor;

using System;
using Shell.Core;

// Checks a model object and reports problems with helpful messages (missing dependency, unbound property, cyclic
// UserWidget, animation conflict, invalid link types ...). Validators run on edit, on load and before export.
interface IValidator
{
	void Validate(Object subject, DiagnosticSink sink);
}
