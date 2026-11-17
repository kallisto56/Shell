namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

// Creates a reusable UserWidget from widgets that already exist in a composition. No separate "symbol" or "prefab" asset is involved: the
// selected widgets become the root of an ordinary composition definition and an instance node takes their place.
//
// Rules (an extraction that cannot follow them is refused with a report and changes nothing):
//   * the selection must be widgets below the same parent, not the definition root; widgets nested in other selected widgets are implied
//   * objects keep their ids (they live in a new scope, so nothing collides); the instance gets a new id
//   * several selected widgets are wrapped in a container root; positions are made relative to the group
//   * the instance takes the position / size of the extracted widgets; the content starts at the origin
//   * outside bindings that read widgets inside become reads of an exposed property of the instance (created automatically)
//   * exposed members of the edited definition that pointed inside are redirected through the instance
//   * bindings inside that read widgets OUTSIDE cannot be preserved (ids are scoped): refused. Parent / owner relative bindings still work
//     and are reported as warnings because their meaning follows the new position in the hierarchy
//   * Blueprint attachments and event hooks move with their widgets
static class UserWidgetExtractor
{
	static void CollectIds(WidgetNodeData node, HashSet<StableId> ids)
	{
		ids.Add(node.mId);
		if (node.mSkin != null && node.mSkin.mRoot != null)
			CollectElementIds(node.mSkin.mRoot, ids);
		for (let child in node.mChildren)
			CollectIds(child, ids);
	}

	static void CollectElementIds(ElementNodeData element, HashSet<StableId> ids)
	{
		ids.Add(element.mId);
		for (let child in element.mChildren)
			CollectElementIds(child, ids);
	}

	static bool IsInside(WidgetNodeData ancestor, WidgetNodeData node)
	{
		if (ancestor == node)
			return true;
		for (let child in ancestor.mChildren)
		{
			if (IsInside(child, node))
				return true;
		}
		return false;
	}

	static int FindBounds(WidgetNodeData node)
	{
		for (int i < node.mProperties.Count)
		{
			if (node.mProperties[i].mName == "Bounds" && node.mProperties[i].mValue.mKind == .Rect)
				return i;
		}
		return -1;
	}

	static ExtractUserWidgetCommand.BoundsChange MakeChange(WidgetNodeData node, int index, Value old, Value value)
	{
		ExtractUserWidgetCommand.BoundsChange change = default;
		change.mNode = node;
		change.mIndex = index;
		change.mOld = old;
		change.mNew = value;
		return change;
	}

	static void Report(List<String> list, StringView text)
	{
		list.Add(new String(text));
	}

	// Public name for an exposed member created by the extraction (unique in the new definition).
	static String UniqueName(CompositionDefinition definition, StringView wanted, ExposedKind kind)
	{
		let name = new String(wanted);
		var counter = 2;
		while (definition.FindExposed(name, kind) != null)
		{
			name.Clear();
			name.AppendF("{}{}", wanted, counter++);
		}
		return name;
	}

	// `types` is optional: with it the kinds of the exposed properties are filled in.
	static public Result<ExtractUserWidgetCommand> Prepare(DefinitionEditSession session, CompositionRegistry registry, StringPool strings, IdGenerator ids,
		List<StableId> selected, StringView name, ExtractionReport report, TypeRegistry types = null)
	{
		let definition = session.mDefinition;
		if (definition.mRoot == null || selected.Count == 0 || name.IsEmpty)
		{
			Report(report.mErrors, "Select at least one widget and give the new UserWidget a name.");
			return .Err;
		}

		let index = DefinitionIndex.Build(definition.mRoot);
		defer delete index;

		// ---- selection ----
		let nodes = scope List<WidgetNodeData>();
		WidgetNodeData parent = null;
		for (let id in selected)
		{
			let found = index.Find(id);
			if (found case .Err)
			{
				Report(report.mErrors, "A selected object does not exist.");
				return .Err;
			}
			let entry = found.Value;
			if (entry.mWidget == null)
			{
				Report(report.mErrors, "Only widgets can be extracted; elements stay part of their widget.");
				return .Err;
			}
			if (entry.mWidget == definition.mRoot)
			{
				Report(report.mErrors, "The root of a composition cannot be extracted; create a UserWidget from its content instead.");
				return .Err;
			}
			if (parent != null && parent != entry.mParentWidget)
			{
				Report(report.mErrors, "The selected widgets must all have the same parent.");
				return .Err;
			}
			parent = entry.mParentWidget;
			nodes.Add(entry.mWidget);
		}
		// widgets nested in other selected widgets are carried along
		for (var i = nodes.Count - 1; i >= 0; i--)
		{
			for (let other in nodes)
			{
				if (other != nodes[i] && IsInside(other, nodes[i]))
				{
					nodes.RemoveAt(i);
					break;
				}
			}
		}
		nodes.Sort(scope (a, b) => parent.mChildren.IndexOf(a) <=> parent.mChildren.IndexOf(b));

		let inside = scope HashSet<StableId>();
		for (let node in nodes)
			CollectIds(node, inside);

		// ---- new objects ----
		let newDefinition = new CompositionDefinition();
		newDefinition.mId = ids.Next();
		newDefinition.mName.Set(name);
		newDefinition.mRevision = 1;

		let instance = new WidgetNodeData();
		instance.mId = ids.Next();
		instance.mName.Set(name);
		instance.mSourceDefinition = newDefinition.mId;

		let command = new ExtractUserWidgetCommand(session, registry);
		command.mNewDefinition = newDefinition;
		command.mInstance = instance;
		command.mParent = parent;
		for (let node in nodes)
		{
			command.mMoved.Add(node);
			command.mOldIndices.Add(parent.mChildren.IndexOf(node));
		}

		// ---- references ----
		let bindings = scope List<(BindingDescriptor binding, StableId owner)>();
		BindingScanner.Collect(definition.mRoot, bindings);
		let exposedKeys = scope List<(StableId target, StringView member, String publicName)>();    // exposed on the new definition
		defer { for (let key in exposedKeys) delete key.publicName; }

		for (let entry in bindings)
		{
			let source = entry.binding.mSource;
			let ownerInside = inside.Contains(entry.owner);
			switch (source.mKind)
			{
			case .WidgetProperty:
				let targetInside = inside.Contains(source.mTarget);
				if (!ownerInside && targetInside)
				{
					// outside reads inside: expose the property and read it from the instance
					String publicName = null;
					for (let key in exposedKeys)
					{
						if (key.target == source.mTarget && key.member == source.mMember)
							publicName = key.publicName;
					}
					if (publicName == null)
					{
						publicName = UniqueName(newDefinition, source.mMember, .Property);
						let member = new ExposedMember();
						member.mId = ids.Next();
						member.mPublicName.Set(publicName);
						member.mKind = .Property;
						member.mInnerTarget = source.mTarget;
						member.mInnerMember = source.mMember;
						member.bWritable = false;
						newDefinition.mExposed.Add(member);
						exposedKeys.Add((source.mTarget, source.mMember, publicName));
						report.mExposedCount++;
					}
					ExtractUserWidgetCommand.BindingRewrite rewrite = default;
					rewrite.mBinding = entry.binding;
					rewrite.mOldTarget = source.mTarget;
					rewrite.mOldMember = source.mMember;
					rewrite.mNewTarget = instance.mId;
					rewrite.mNewMember = strings.Intern(publicName);
					command.mBindingRewrites.Add(rewrite);
					report.mRewrittenBindings++;
				}
				else if (ownerInside && source.mTarget.mIsValid && !targetInside)
				{
					Report(report.mErrors, scope $"A binding inside the selection reads the widget {source.mTarget}, which stays outside. Expose that value through a property of the new UserWidget first, or include the widget in the selection.");
				}
			case .OwnerProperty, .ParentProperty:
				if (ownerInside)
					Report(report.mWarnings, scope $"The binding of '{entry.binding.mTargetProperty}' reads its parent / owner; it now follows the position of the UserWidget in the hierarchy.");
			case .BlueprintVariable, .AnimationInput:
				if (!ownerInside && inside.Contains(source.mTarget))
					Report(report.mErrors, scope $"An outside binding reads '{source.mMember}' of an object that moves into the new UserWidget; Blueprint and animation sources cannot be redirected yet.");
				else if (ownerInside && source.mTarget.mIsValid && !inside.Contains(source.mTarget))
					Report(report.mErrors, scope $"A binding inside the selection reads '{source.mMember}' of an object that stays outside.");
			default:
			}
		}

		// exposed members of the edited definition that point into the moved part
		for (let member in definition.mExposed)
		{
			if (!inside.Contains(member.mInnerTarget))
				continue;
			let publicName = UniqueName(newDefinition, member.mInnerMember, member.mKind);
			let inner = new ExposedMember();
			inner.mId = ids.Next();
			inner.mPublicName.Set(publicName);
			inner.mKind = member.mKind;
			inner.mValueKind = member.mValueKind;
			inner.mInnerTarget = member.mInnerTarget;
			inner.mInnerMember = member.mInnerMember;
			inner.bWritable = member.bWritable;
			newDefinition.mExposed.Add(inner);
			delete publicName;

			ExtractUserWidgetCommand.ExposedRewrite rewrite = default;
			rewrite.mMember = member;
			rewrite.mOldTarget = member.mInnerTarget;
			rewrite.mOldMember = member.mInnerMember;
			rewrite.mNewTarget = instance.mId;
			rewrite.mNewMember = strings.Intern(inner.mPublicName);
			command.mExposedRewrites.Add(rewrite);
		}

		// kinds of the exposed properties
		if (types != null)
		{
			for (let member in newDefinition.mExposed)
			{
				if (member.mKind != .Property || member.mValueKind != .None)
					continue;
				let found = index.Find(member.mInnerTarget);
				if (found case .Err)
					continue;
				let entry = found.Value;
				TypeDescriptor type = null;
				if (entry.mWidget != null && !entry.mWidget.mIsInstance)
					type = types.Find(entry.mWidget.mTypeName);
				else if (entry.mElement != null)
					type = entry.mElement.mTypeName.IsEmpty ? ElementTypes.TypeFor(entry.mElement.mKind) : types.Find(entry.mElement.mTypeName);
				let property = (type != null) ? type.FindProperty(member.mInnerMember) : null;
				if (property != null)
					member.mValueKind = property.mValueKind;
			}
		}

		if (!report.mIsOk)
		{
			delete command;
			return .Err;
		}

		// ---- layout of the new composition ----
		if (nodes.Count > 1)
		{
			let group = new WidgetNodeData();
			group.mId = ids.Next();
			group.mTypeName = strings.Intern("Container");
			group.mName.Set(name);
			command.mGroupRoot = group;
		}

		RectF union = default;
		bool bAny = false;
		for (let node in nodes)
		{
			let at = FindBounds(node);
			if (at < 0)
				continue;
			let v = node.mProperties[at].mValue;
			let rect = RectF(v.mX, v.mY, v.mZ, v.mW);
			union = bAny ? RectF(Math.Min(union.mX, rect.mX), Math.Min(union.mY, rect.mY),
				Math.Max(union.mRight, rect.mRight) - Math.Min(union.mX, rect.mX), Math.Max(union.mBottom, rect.mBottom) - Math.Min(union.mY, rect.mY)) : rect;
			bAny = true;
		}
		if (bAny)
		{
			// instance: union rectangle in the parent; content: starts at the origin
			PropertyValueData bounds = default;
			bounds.mName = strings.Intern("Bounds");
			bounds.mValue = Value.FromRect(union.mX, union.mY, union.mWidth, union.mHeight);
			instance.mProperties.Add(bounds);

			if (nodes.Count == 1)
			{
				let at = FindBounds(nodes[0]);
				command.mBoundsChanges.Add(MakeChange(nodes[0], at, nodes[0].mProperties[at].mValue, Value.FromRect(0, 0, union.mWidth, union.mHeight)));
			}
			else
			{
				PropertyValueData groupBounds = default;
				groupBounds.mName = strings.Intern("Bounds");
				groupBounds.mValue = Value.FromRect(0, 0, union.mWidth, union.mHeight);
				command.mGroupRoot.mProperties.Add(groupBounds);
				for (let node in nodes)
				{
					let at = FindBounds(node);
					if (at < 0)
						continue;
					let v = node.mProperties[at].mValue;
					command.mBoundsChanges.Add(MakeChange(node, at, v, Value.FromRect(v.mX - union.mX, v.mY - union.mY, v.mZ, v.mW)));
				}
			}
		}
		return .Ok(command);
	}
}
