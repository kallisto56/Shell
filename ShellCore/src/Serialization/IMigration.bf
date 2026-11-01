namespace Shell.Serialization;

using System;
using Shell.Core;

// Upgrades a parsed document by exactly one schema step (From -> To). Migrations are pure functions of the document.
interface IMigration
{
	SchemaVersion GetFrom();
	SchemaVersion GetTo();
	Result<void> Migrate(Document document, DiagnosticSink sink);
}
