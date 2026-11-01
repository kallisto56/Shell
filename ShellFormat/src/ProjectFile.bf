namespace Shell.Format;

using System;
using System.Collections;
using System.IO;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Elements;
using Shell.Blueprints;
using Shell.Composition;
using Shell.Animation;
using Shell.Styling;
using Shell.Serialization;
using Shell.Platform;

// Loading and saving of project files.
//   Load:  text -> Document (TextReader) -> migrations to the current schema -> ShellProject (ProjectSerializer) -> validation
//   Save:  ShellProject -> Document -> text; deterministic, so unchanged projects produce byte-identical files
// Failures are reported through the DiagnosticSink; the returned Result only says whether a usable project exists.
static class ProjectFile
{
	static public Result<ShellProject> LoadFromText(StringView text, MigrationRegistry migrations, DiagnosticSink sink)
	{
		let errorsBefore = sink.mErrorCount;

		Document document;
		if (TextReader.Parse(text, sink) case .Ok(let parsed))
			document = parsed;
		else
			return .Err;
		defer delete document;

		if (migrations.MigrateToCurrent(document, sink) case .Err)
			return .Err;
		if (document.mVersion.IsNewerThan(FormatInfo.sCurrent))
			sink.Warning("SER0003", scope $"The file was written by a newer minor version ({document.mVersion}); fields this version does not know are ignored.");

		let project = ProjectSerializer.Read(document, sink);
		if (project == null)
			return .Err;

		ProjectValidator.Validate(project, sink);
		if (sink.mErrorCount > errorsBefore)
		{
			delete project;
			return .Err;
		}
		return .Ok(project);
	}

	static public Result<ShellProject> Load(StringView path, MigrationRegistry migrations, DiagnosticSink sink)
	{
		let text = scope String();
		if (File.ReadAllText(path, text) case .Err)
		{
			sink.Error("SER0004", scope $"The file '{path}' could not be read.");
			return .Err;
		}
		return LoadFromText(text, migrations, sink);
	}

	static public Result<void> SaveToText(ShellProject project, String output, DiagnosticSink sink)
	{
		let errorsBefore = sink.mErrorCount;
		ProjectValidator.Validate(project, sink);
		if (sink.mErrorCount > errorsBefore)
			return .Err;

		let document = ProjectSerializer.Write(project, sink);
		defer delete document;
		if (!TextWriter.Write(document, output, sink))
			return .Err;
		return .Ok;
	}

	// Writes to "<path>.tmp" first and replaces the target afterwards, so a crash never leaves a half written project.
	static public Result<void> Save(ShellProject project, StringView path, DiagnosticSink sink)
	{
		let text = scope String();
		if (SaveToText(project, text, sink) case .Err)
			return .Err;

		let temp = scope String(path);
		temp.Append(".tmp");
		if (File.WriteAllText(temp, text) case .Err)
		{
			sink.Error("SER0005", scope $"The file '{temp}' could not be written.");
			return .Err;
		}
		if (File.Exists(path))
			File.Delete(path);
		if (File.Move(temp, path) case .Err)
		{
			sink.Error("SER0005", scope $"The file '{path}' could not be replaced.");
			return .Err;
		}
		return .Ok;
	}
}
