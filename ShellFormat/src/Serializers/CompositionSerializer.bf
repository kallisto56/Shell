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

static class CompositionSerializer
{
	static public void Write(CompositionDefinition definition, DocumentNode node, SerializationContext context)
	{
		let w = scope NodeWriter(node, context);
		w.Str("Name", definition.mName);
		w.Int("Revision", definition.mRevision);

		if (definition.mRoot != null)
		{
			let group = w.Group("root");
			WidgetSerializer.Write(definition.mRoot, NodeWriter.AddNode(group, "Widget", definition.mRoot.mId), context);
		}
		if (definition.mBlueprints.Count > 0)
		{
			let group = w.Group("blueprints");
			for (let asset in definition.mBlueprints)
				BlueprintSerializer.Write(asset, NodeWriter.AddNode(group, "Blueprint", asset.mId), context);
		}
		if (definition.mClips.Count > 0)
		{
			let group = w.Group("clips");
			for (let clip in definition.mClips)
				AnimationSerializer.WriteClip(clip, NodeWriter.AddNode(group, "Clip", clip.mId), context);
		}
		if (definition.mStateMachines.Count > 0)
		{
			let group = w.Group("stateMachines");
			for (let machine in definition.mStateMachines)
				AnimationSerializer.WriteMachine(machine, NodeWriter.AddNode(group, "StateMachine", machine.mId), context);
		}
		if (definition.mExposed.Count > 0)
		{
			let group = w.Group("exposed");
			for (let member in definition.mExposed)
			{
				let en = NodeWriter.AddNode(group, "Exposed", member.mId);
				let ew = scope NodeWriter(en, context);
				ew.Str("PublicName", member.mPublicName);
				ew.Enum("Kind", member.mKind);
				ew.Enum("Type", member.mValueKind);
				ew.IdAlways("Target", member.mInnerTarget);
				ew.Str("Member", member.mInnerMember);
				ew.Bool("Writable", member.bWritable);
			}
		}
	}

	static public CompositionDefinition Read(DocumentNode node, SerializationContext context)
	{
		let r = scope NodeReader(node, context);
		let definition = new CompositionDefinition();
		definition.mId = node.mId;
		r.StrInto("Name", definition.mName);
		definition.mRevision = (uint32)r.Int("Revision");

		let root = r.Group("root");
		if (root != null && root.mNodes.Count > 0)
			definition.mRoot = WidgetSerializer.Read(root.mNodes[0], context);

		let blueprints = r.Group("blueprints");
		if (blueprints != null)
		{
			for (let n in blueprints.mNodes)
				definition.mBlueprints.Add(BlueprintSerializer.Read(n, context));
		}
		let clips = r.Group("clips");
		if (clips != null)
		{
			for (let n in clips.mNodes)
				definition.mClips.Add(AnimationSerializer.ReadClip(n, context));
		}
		let machines = r.Group("stateMachines");
		if (machines != null)
		{
			for (let n in machines.mNodes)
				definition.mStateMachines.Add(AnimationSerializer.ReadMachine(n, context));
		}
		let exposed = r.Group("exposed");
		if (exposed != null)
		{
			for (let n in exposed.mNodes)
			{
				let er = scope NodeReader(n, context);
				let member = new ExposedMember();
				member.mId = n.mId;
				er.StrInto("PublicName", member.mPublicName, true);
				member.mKind = er.Enum("Kind", ExposedKind.Property);
				member.mValueKind = er.Enum("Type", ValueKind.None);
				member.mInnerTarget = er.Id("Target", true);
				member.mInnerMember = er.Str("Member", true);
				member.bWritable = er.Bool("Writable");
				er.ReportUnknown();
				definition.mExposed.Add(member);
			}
		}
		r.ReportUnknown();
		return definition;
	}
}
