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

static class WidgetSerializer
{
	static public void Write(WidgetNodeData widget, DocumentNode node, SerializationContext context)
	{
		let w = scope NodeWriter(node, context);
		w.StrIf("Type", widget.mTypeName);
		w.StrIf("Name", widget.mName);
		w.Id("Definition", widget.mSourceDefinition);
		w.Id("Style", widget.mComponentStyle);
		PropertyValues.Write(widget.mProperties, w);
		BindingSerializer.WriteList(widget.mBindings, w);

		if (widget.mOverrides.Count > 0)
		{
			let group = w.Group("overrides");
			for (let entry in widget.mOverrides)
			{
				let child = NodeWriter.AddNode(group, "Override", .sNone);
				let ow = scope NodeWriter(child, context);
				ow.Str("Property", entry.mProperty);
				ow.Val("Value", entry.mValue);
				for (int i < entry.mPath.Count)
					ow.IdAlways(scope $"path{i}", entry.mPath[i]);
			}
		}

		if (widget.mEventHooks.Count > 0)
		{
			let group = w.Group("hooks");
			for (let hook in widget.mEventHooks)
			{
				let child = NodeWriter.AddNode(group, "EventHook", hook.mId);
				let hw = scope NodeWriter(child, context);
				hw.Str("Event", hook.mWidgetEvent);
				hw.IdAlways("Blueprint", hook.mBlueprint);
				hw.Str("BlueprintEvent", hook.mBlueprintEvent);
			}
		}

		if (widget.mBlueprints.Count > 0)
		{
			let group = w.Group("blueprints");
			for (let attachment in widget.mBlueprints)
			{
				let child = NodeWriter.AddNode(group, "Attachment", attachment.mInstanceId);
				let aw = scope NodeWriter(child, context);
				aw.IdAlways("Blueprint", attachment.mBlueprint);
			}
		}

		if (widget.mSkin != null)
		{
			let group = w.Group("skin");
			ElementSerializer.WriteTree(widget.mSkin, NodeWriter.AddNode(group, "Skin", .sNone), context);
		}

		if (widget.mChildren.Count > 0)
		{
			let group = w.Group("children");
			for (let child in widget.mChildren)
				Write(child, NodeWriter.AddNode(group, "Widget", child.mId), context);
		}
	}

	static public WidgetNodeData Read(DocumentNode node, SerializationContext context)
	{
		let r = scope NodeReader(node, context);
		let widget = new WidgetNodeData();
		widget.mId = node.mId;
		widget.mTypeName = r.Str("Type");
		r.StrInto("Name", widget.mName);
		widget.mSourceDefinition = r.Id("Definition");
		widget.mComponentStyle = r.Id("Style");
		PropertyValues.Read(r, widget.mProperties);
		BindingSerializer.ReadList(r, "bindings", widget.mBindings);

		let overrides = r.Group("overrides");
		if (overrides != null)
		{
			for (let child in overrides.mNodes)
			{
				let orr = scope NodeReader(child, context);
				let entry = new OverrideEntry();
				entry.mProperty = orr.Str("Property", true);
				entry.mValue = orr.Val("Value");
				for (var i = 0; orr.Has(scope $"path{i}"); i++)
					entry.mPath.Add(orr.Id(scope $"path{i}"));
				orr.ReportUnknown();
				widget.mOverrides.Add(entry);
			}
		}

		let hooks = r.Group("hooks");
		if (hooks != null)
		{
			for (let child in hooks.mNodes)
			{
				let hr = scope NodeReader(child, context);
				EventHookData hook = default;
				hook.mId = child.mId;
				hook.mWidgetEvent = hr.Str("Event", true);
				hook.mBlueprint = hr.Id("Blueprint", true);
				hook.mBlueprintEvent = hr.Str("BlueprintEvent", true);
				hr.ReportUnknown();
				widget.mEventHooks.Add(hook);
			}
		}

		let blueprints = r.Group("blueprints");
		if (blueprints != null)
		{
			for (let child in blueprints.mNodes)
			{
				let br = scope NodeReader(child, context);
				BlueprintAttachment attachment = default;
				attachment.mInstanceId = child.mId;
				attachment.mBlueprint = br.Id("Blueprint", true);
				br.ReportUnknown();
				widget.mBlueprints.Add(attachment);
			}
		}

		let skin = r.Group("skin");
		if (skin != null && skin.mNodes.Count > 0)
			widget.mSkin = ElementSerializer.ReadTree(skin.mNodes[0], context);

		let children = r.Group("children");
		if (children != null)
		{
			for (let child in children.mNodes)
				widget.mChildren.Add(Read(child, context));
		}
		r.ReportUnknown();
		return widget;
	}
}
