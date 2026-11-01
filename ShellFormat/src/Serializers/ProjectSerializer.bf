namespace Shell.Format;

using System;
using System.Collections;
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

// Project <-> Document. Order in the file is fixed: manifest fields, then groups globals, themes, styles, blueprints,
// compositions (each in the model's list order), so a save/load/save round trip is byte-identical.
static class ProjectSerializer
{
	static public Document Write(ShellProject project, DiagnosticSink sink)
	{
		let document = new Document();
		document.mVersion = FormatInfo.sCurrent;
		let context = scope SerializationContext(sink, project.mStrings, document);

		let root = new DocumentNode();
		root.mType.Set("Project");
		root.mId = project.mManifest.mId;
		document.mRoot = root;

		let w = scope NodeWriter(root, context);
		w.Str("Name", project.mManifest.mName);
		w.Flags("Requested", (uint32)project.mManifest.mRequested);
		for (int i < project.mManifest.mDependencies.Count)
			w.IdAlways(scope $"dep{i}", project.mManifest.mDependencies[i]);
		w.Id("Entry", project.mEntryComposition);

		if (project.mGlobals.Count > 0)
		{
			let group = w.Group("globals");
			for (let global in project.mGlobals)
				StyleSerializer.WriteGlobal(global, NodeWriter.AddNode(group, "Global", global.mId), context);
		}
		if (project.mThemes.Count > 0)
		{
			let group = w.Group("themes");
			for (let theme in project.mThemes)
				StyleSerializer.WriteTheme(theme, NodeWriter.AddNode(group, "Theme", theme.mId), context);
		}
		if (project.mStyles.Count > 0)
		{
			let group = w.Group("styles");
			for (let style in project.mStyles)
				StyleSerializer.WriteStyle(style, NodeWriter.AddNode(group, "Style", style.mId), context);
		}
		if (project.mBlueprints.Count > 0)
		{
			let group = w.Group("blueprints");
			for (let asset in project.mBlueprints)
				BlueprintSerializer.Write(asset, NodeWriter.AddNode(group, "Blueprint", asset.mId), context);
		}

		let compositions = scope List<CompositionDefinition>();
		project.mCompositions.GetAll(compositions);
		if (compositions.Count > 0)
		{
			let group = w.Group("compositions");
			for (let definition in compositions)
				CompositionSerializer.Write(definition, NodeWriter.AddNode(group, "Composition", definition.mId), context);
		}
		return document;
	}

	// The document must already be migrated to the current version.
	static public ShellProject Read(Document document, DiagnosticSink sink)
	{
		let project = new ShellProject();
		let context = scope SerializationContext(sink, project.mStrings, document);
		let root = document.mRoot;

		if (root.mType != "Project")
		{
			sink.Error("SER0401", scope $"The root node must be a 'Project', found '{root.mType}'.");
			delete project;
			return null;
		}

		let r = scope NodeReader(root, context);
		project.mManifest.mId = root.mId;
		r.StrInto("Name", project.mManifest.mName);
		project.mManifest.mFormat = document.mVersion;
		project.mManifest.mRequested = (Capability)r.Flags("Requested");
		for (var i = 0; r.Has(scope $"dep{i}"); i++)
			project.mManifest.mDependencies.Add(r.Id(scope $"dep{i}"));
		project.mEntryComposition = r.Id("Entry");

		let globals = r.Group("globals");
		if (globals != null)
		{
			for (let n in globals.mNodes)
				project.mGlobals.Add(StyleSerializer.ReadGlobal(n, context));
		}
		let themes = r.Group("themes");
		if (themes != null)
		{
			for (let n in themes.mNodes)
				project.mThemes.Add(StyleSerializer.ReadTheme(n, context));
		}
		let styles = r.Group("styles");
		if (styles != null)
		{
			for (let n in styles.mNodes)
				project.mStyles.Add(StyleSerializer.ReadStyle(n, context));
		}
		let blueprints = r.Group("blueprints");
		if (blueprints != null)
		{
			for (let n in blueprints.mNodes)
				project.mBlueprints.Add(BlueprintSerializer.Read(n, context));
		}
		let compositions = r.Group("compositions");
		if (compositions != null)
		{
			for (let n in compositions.mNodes)
				project.mCompositions.Add(CompositionSerializer.Read(n, context), sink);
		}
		r.ReportUnknown();
		return project;
	}
}
