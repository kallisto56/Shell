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
using Shell.Widgets;

// Structural validation of a loaded or edited project. Reports problems with stable codes (VAL....) and the id of the
// offending object; never throws away data.
static class ProjectValidator
{
	class IdCollector
	{
		public Dictionary<StableId, String> mKinds = new .() ~ DeleteDictionaryAndValues!(_);
		public DiagnosticSink mSink;

		public void Add(StableId id, StringView kind)
		{
			if (!id.mIsValid)
			{
				mSink.Error("VAL0002", scope $"A {kind} has no id.");
				return;
			}
			if (mKinds.TryGetValue(id, let existing))
			{
				mSink.Error("VAL0001", scope $"The id {id} is used by a {kind} and by a {existing}.", id);
				return;
			}
			mKinds[id] = new String(kind);
		}
	}

	static public void Validate(ShellProject project, DiagnosticSink sink)
	{
		let ids = scope IdCollector();
		ids.mSink = sink;
		ids.Add(project.mManifest.mId, "project");

		// Globals: unique names
		let names = scope HashSet<String>();
		let ownedNames = scope List<String>();
		defer { for (let n in ownedNames) delete n; }
		for (let global in project.mGlobals)
		{
			ids.Add(global.mId, "global variable");
			let name = new String(global.mName);
			ownedNames.Add(name);
			if (!names.Add(name))
				sink.Error("VAL0501", scope $"The global variable name '{global.mName}' is defined twice.", global.mId);
		}

		// Themes
		for (let theme in project.mThemes)
		{
			ids.Add(theme.mId, "theme");
			for (let token in theme.mTokens)
				ids.Add(token.mId, "design token");
			if (theme.mParent.mIsValid && project.FindTheme(theme.mParent) == null)
				sink.Error("VAL0103", scope $"Theme '{theme.mName}' uses the missing theme {theme.mParent} as its parent.", theme.mId);
			CheckThemeCycle(project, theme, sink);
		}

		// Styles
		let styleIds = scope HashSet<StableId>();
		for (let style in project.mStyles)
			styleIds.Add(style.mId);
		for (let style in project.mStyles)
		{
			ids.Add(style.mId, "component style");
			for (let rule in style.mRules)
				ids.Add(rule.mId, "style rule");
			if (style.mBaseStyle.mIsValid && !styleIds.Contains(style.mBaseStyle))
				sink.Error("VAL0104", scope $"Style '{style.mName}' uses the missing style {style.mBaseStyle} as its base.", style.mId);
		}

		// Shared blueprints
		for (let asset in project.mBlueprints)
			ValidateBlueprint(asset, ids, sink);

		// Compositions
		let definitions = scope List<CompositionDefinition>();
		project.mCompositions.GetAll(definitions);
		for (let definition in definitions)
			ValidateComposition(project, definition, styleIds, ids, sink);

		if (project.mEntryComposition.mIsValid && project.mCompositions.Find(project.mEntryComposition) == null)
			sink.Error("VAL0105", scope $"The entry composition {project.mEntryComposition} does not exist.", project.mEntryComposition);
	}

	static void CheckThemeCycle(ShellProject project, Theme start, DiagnosticSink sink)
	{
		var current = start;
		for (int i < 64)
		{
			if (!current.mParent.mIsValid)
				return;
			current = project.FindTheme(current.mParent);
			if (current == null)
				return;
			if (current == start)
			{
				sink.Error("VAL0106", scope $"Theme '{start.mName}' is its own ancestor.", start.mId);
				return;
			}
		}
	}

	static void ValidateBlueprint(BlueprintAsset asset, IdCollector ids, DiagnosticSink sink)
	{
		ids.Add(asset.mId, "blueprint");
		let variableIds = scope HashSet<StableId>();
		for (let variable in asset.mVariables)
		{
			ids.Add(variable.mId, "blueprint variable");
			variableIds.Add(variable.mId);
		}
		for (let id in asset.mInterface.mPublicVariables)
		{
			if (!variableIds.Contains(id))
				sink.Error("VAL0210", scope $"Blueprint '{asset.mName}' publishes the missing variable {id}.", asset.mId);
		}
		for (let fn in asset.mInterface.mFunctions)
			ids.Add(fn.mId, "blueprint function");
		for (let ev in asset.mInterface.mEvents)
			ids.Add(ev.mId, "blueprint event");

		for (let graph in asset.mGraphs)
		{
			ids.Add(graph.mId, "graph");
			for (let local in graph.mLocals)
				ids.Add(local.mId, "local variable");

			let pins = scope Dictionary<StableId, Pin>();
			let pinNodes = scope Dictionary<StableId, StableId>();
			for (let node in graph.mNodes)
			{
				ids.Add(node.mId, "graph node");
				for (let pin in node.mPins)
				{
					ids.Add(pin.mId, "pin");
					pins[pin.mId] = pin;
					pinNodes[pin.mId] = node.mId;
				}
			}

			for (let link in graph.mLinks)
			{
				ids.Add(link.mId, "link");
				var a = pins.TryGetValue(link.mFromPin, let from);
				var b = pins.TryGetValue(link.mToPin, let to);
				if (!a || !b)
				{
					sink.Error("VAL0201", "A link connects a pin that does not exist.", link.mId);
					continue;
				}
				if (pinNodes[link.mFromPin] != link.mFromNode || pinNodes[link.mToPin] != link.mToNode)
					sink.Error("VAL0202", "A link names a node that does not own the pin.", link.mId);
				if (from.mDirection != .Out || to.mDirection != .In)
					sink.Error("VAL0203", "A link must go from an output pin to an input pin.", link.mId);
				if (from.mCategory != to.mCategory)
					sink.Error("VAL0204", "A link connects an execution pin to a data pin.", link.mId);
				else if (from.mCategory == .Data && from.mKind != to.mKind)
					sink.Error("VAL0205", scope $"A link connects a {from.mKind} output to a {to.mKind} input; insert a conversion node.", link.mId);
			}
		}
	}

	static void CollectWidgetIds(WidgetNodeData widget, HashSet<StableId> output)
	{
		output.Add(widget.mId);
		for (let attachment in widget.mBlueprints)
			output.Add(attachment.mInstanceId);
		if (widget.mSkin != null && widget.mSkin.mRoot != null)
			CollectElementIds(widget.mSkin.mRoot, output);
		for (let child in widget.mChildren)
			CollectWidgetIds(child, output);
	}

	static void CollectElementIds(ElementNodeData element, HashSet<StableId> output)
	{
		output.Add(element.mId);
		for (let child in element.mChildren)
			CollectElementIds(child, output);
	}

	static void ValidateElement(ElementNodeData element, HashSet<StableId> layerIds, IdCollector ids, DiagnosticSink sink)
	{
		ids.Add(element.mId, "element");
		if (element.mLayer.mIsValid && !layerIds.Contains(element.mLayer))
			sink.Error("VAL0108", scope $"Element '{element.mName}' is assigned to the missing layer {element.mLayer}.", element.mId);
		for (let binding in element.mBindings)
			ids.Add(binding.mId, "binding");
		for (let effect in element.mEffects)
			ids.Add(effect.mId, "effect");
		for (let child in element.mChildren)
			ValidateElement(child, layerIds, ids, sink);
	}

	static void ValidateWidget(ShellProject project, CompositionDefinition owner, WidgetNodeData widget, HashSet<StableId> styleIds,
		HashSet<StableId> blueprintIds, IdCollector ids, DiagnosticSink sink)
	{
		ids.Add(widget.mId, "widget");
		if (widget.mIsInstance && project.mCompositions.Find(widget.mSourceDefinition) == null)
			sink.Error("VAL0101", scope $"Widget '{widget.mName}' in '{owner.mName}' is an instance of the missing UserWidget {widget.mSourceDefinition}.", widget.mId);
		if (widget.mComponentStyle.mIsValid && !styleIds.Contains(widget.mComponentStyle))
			sink.Error("VAL0104", scope $"Widget '{widget.mName}' uses the missing style {widget.mComponentStyle}.", widget.mId);
		for (let binding in widget.mBindings)
			ids.Add(binding.mId, "binding");
		for (let hook in widget.mEventHooks)
		{
			ids.Add(hook.mId, "event hook");
			if (!blueprintIds.Contains(hook.mBlueprint))
				sink.Error("VAL0107", scope $"An event hook of '{widget.mName}' refers to the missing Blueprint {hook.mBlueprint}.", hook.mId);
		}
		for (let attachment in widget.mBlueprints)
		{
			if (!blueprintIds.Contains(attachment.mBlueprint))
				sink.Error("VAL0107", scope $"Widget '{widget.mName}' has the missing Blueprint {attachment.mBlueprint} attached.", widget.mId);
		}

		if (widget.mSkin != null)
		{
			let layerIds = scope HashSet<StableId>();
			bool bContent = false;
			for (let layer in widget.mSkin.mLayers)
			{
				ids.Add(layer.mId, "layer");
				layerIds.Add(layer.mId);
				if (layer.mRole == .Content)
					bContent = true;
			}
			if (widget.mSkin.mRoot != null && !bContent)
				sink.Error("VAL0109", scope $"The skin of '{widget.mName}' has no Content layer.", widget.mId);
			if (widget.mSkin.mRoot != null)
				ValidateElement(widget.mSkin.mRoot, layerIds, ids, sink);
		}

		for (let child in widget.mChildren)
			ValidateWidget(project, owner, child, styleIds, blueprintIds, ids, sink);
	}

	static void ValidateComposition(ShellProject project, CompositionDefinition definition, HashSet<StableId> styleIds, IdCollector ids, DiagnosticSink sink)
	{
		ids.Add(definition.mId, "composition");

		let blueprintIds = scope HashSet<StableId>();
		for (let asset in project.mBlueprints)
			blueprintIds.Add(asset.mId);
		for (let asset in definition.mBlueprints)
		{
			blueprintIds.Add(asset.mId);
			ValidateBlueprint(asset, ids, sink);
		}

		let objectIds = scope HashSet<StableId>();
		if (definition.mRoot != null)
		{
			CollectWidgetIds(definition.mRoot, objectIds);
			ValidateWidget(project, definition, definition.mRoot, styleIds, blueprintIds, ids, sink);
		}

		let path = scope List<StableId>();
		if (project.mCompositions.FindCycle(definition.mId, path))
			sink.Error("VAL0102", scope $"UserWidget '{definition.mName}' contains itself (directly or through other UserWidgets).", definition.mId);

		// Exposed members
		let publicNames = scope HashSet<String>();
		let owned = scope List<String>();
		defer { for (let n in owned) delete n; }
		for (let member in definition.mExposed)
		{
			ids.Add(member.mId, "exposed member");
			let key = new String();
			key.AppendF("{}:{}", member.mKind, member.mPublicName);
			owned.Add(key);
			if (!publicNames.Add(key))
				sink.Error("VAL0302", scope $"The public {member.mKind} name '{member.mPublicName}' is exposed twice in '{definition.mName}'.", member.mId);
			if (!objectIds.Contains(member.mInnerTarget))
			{
				bool bBlueprintAttachment = false;
				for (let asset in definition.mBlueprints)
					if (asset.mId == member.mInnerTarget) bBlueprintAttachment = true;
				if (!bBlueprintAttachment)
					sink.Error("VAL0301", scope $"The exposed member '{member.mPublicName}' targets {member.mInnerTarget}, which does not exist in '{definition.mName}'.", member.mId);
			}
		}

		// Animation
		let clipIds = scope HashSet<StableId>();
		for (let clip in definition.mClips)
		{
			ids.Add(clip.mId, "animation clip");
			clipIds.Add(clip.mId);
			for (let track in clip.mTracks)
			{
				ids.Add(track.mId, "animation track");
				if (!objectIds.Contains(track.mTarget))
					sink.Error("VAL0401", scope $"A track of clip '{clip.mName}' animates {track.mTarget}, which does not exist in '{definition.mName}'.", track.mId);
			}
		}
		for (let machine in definition.mStateMachines)
		{
			ids.Add(machine.mId, "state machine");
			let stateIds = scope HashSet<StableId>();
			let inputIds = scope HashSet<StableId>();
			for (let input in machine.mInputs) { ids.Add(input.mId, "animation input"); inputIds.Add(input.mId); }
			for (let state in machine.mStates)
			{
				ids.Add(state.mId, "animation state");
				stateIds.Add(state.mId);
				if (state.mContent == .Clip && !clipIds.Contains(state.mContentId))
					sink.Error("VAL0403", scope $"State '{state.mName}' plays the missing clip {state.mContentId}.", state.mId);
			}
			for (let tree in machine.mBlendTrees)
			{
				ids.Add(tree.mId, "blend tree");
				for (let entry in tree.mEntries)
				{
					if (!clipIds.Contains(entry.mClip))
						sink.Error("VAL0403", scope $"Blend tree '{tree.mName}' uses the missing clip {entry.mClip}.", tree.mId);
				}
			}
			if (machine.mEntryState.mIsValid && !stateIds.Contains(machine.mEntryState))
				sink.Error("VAL0402", scope $"The entry state of '{machine.mName}' does not exist.", machine.mId);
			for (let transition in machine.mTransitions)
			{
				ids.Add(transition.mId, "transition");
				if (!stateIds.Contains(transition.mTo) || (transition.mFrom.mIsValid && !stateIds.Contains(transition.mFrom)))
					sink.Error("VAL0402", scope $"A transition of '{machine.mName}' refers to a missing state.", transition.mId);
				for (let condition in transition.mConditions)
				{
					if (!inputIds.Contains(condition.mInput))
						sink.Error("VAL0404", scope $"A transition condition of '{machine.mName}' refers to a missing input.", transition.mId);
				}
			}
		}
	}
}
