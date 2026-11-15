namespace Shell.Serialization;

using System;
using System.Collections;
using Shell.Core;

// Registered migrations and the chain logic: find and run the steps that take a document from its version to the
// current one. Files from a *newer* major version are refused with a clear message instead of being half-loaded.
class MigrationRegistry
{
	List<IMigration> mMigrations = new .() ~ DeleteContainerAndItems!(_);

	public void Register(IMigration migration)
	{
		mMigrations.Add(migration);
	}

	public Result<void> MigrateToCurrent(Document document, DiagnosticSink sink)
	{
		let target = FormatInfo.sCurrent;
		if (document.mVersion.mMajor > target.mMajor)
		{
			sink.Error("SER0001", scope $"The file uses format {document.mVersion}, newer than this application understands ({target}).");
			return .Err;
		}

		int guard = 0;
		while (document.mVersion.mMajor < target.mMajor)
		{
			IMigration step = null;
			for (let migration in mMigrations)
			{
				if (migration.GetFrom() == document.mVersion)
				{
					step = migration;
					break;
				}
			}
			if (step == null || ++guard > 64)
			{
				sink.Error("SER0002", scope $"No migration path from format {document.mVersion} to {target}.");
				return .Err;
			}
			if (step.Migrate(document, sink) case .Err)
				return .Err;
			document.mVersion = step.GetTo();
		}
		return .Ok;
	}
}
