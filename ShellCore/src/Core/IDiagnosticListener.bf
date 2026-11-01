namespace Shell.Core;

using System;

interface IDiagnosticListener
{
	void OnDiagnostic(Diagnostic diagnostic);
}
