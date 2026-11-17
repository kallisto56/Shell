namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

// Editing of the public interface of a UserWidget definition.
//   Expose   : publish a property / event / method of an inner widget or element (or of a nested instance) under a public name
//   Unexpose : hide it again; refused while instances or bindings still use it, unless forced (they then report the missing member)
//   Rename   : change the public name; saved instance values and bindings are rewritten, so nothing breaks
// Changes bump the definition's revision, which propagates them to live instances.
class DefinitionEditor
{
	DefinitionEditSession mSession;
	CompositionRegistry mRegistry;
	CommandStack mStack;
	StringPool mStrings;
	TypeRegistry mTypes;

	public this(DefinitionEditSession session, CompositionRegistry registry, CommandStack stack, StringPool strings, TypeRegistry types = null)
	{
		mSession = session;
		mRegistry = registry;
		mStack = stack;
		mStrings = strings;
		mTypes = types;
	}

	public Result<StableId, EditError> Expose(ExposedKind kind, StringView publicName, StableId innerTarget, StringView innerMember, bool writable, IdGenerator ids)
	{
		let definition = mSession.mDefinition;
		if (publicName.IsEmpty || innerMember.IsEmpty)
			return .Err(.InvalidTarget);
		if (definition.FindExposed(publicName, kind) != null)
			return .Err(.Duplicate);

		let index = DefinitionIndex.Build(definition.mRoot);
		defer delete index;
		let found = index.Find(innerTarget);
		if (found case .Err)
			return .Err(.NotFound);
		let entry = found.Value;

		// Primitive targets can be checked against their type; nested instances are checked when the instance type is built.
		ValueKind valueKind = .None;
		TypeDescriptor type = null;
		if (entry.mElement != null)
			type = entry.mElement.mTypeName.IsEmpty ? ElementTypes.TypeFor(entry.mElement.mKind) : ((mTypes != null) ? mTypes.Find(entry.mElement.mTypeName) : null);
		else if (entry.mWidget != null && !entry.mWidget.mIsInstance && mTypes != null)
			type = mTypes.Find(entry.mWidget.mTypeName);
		if (type != null)
		{
			switch (kind)
			{
			case .Property:
				let property = type.FindProperty(innerMember);
				if (property == null)
					return .Err(.NotFound);
				valueKind = property.mValueKind;
			case .Event:
				if (type.FindEvent(innerMember) == null)
					return .Err(.NotFound);
			case .Method:
				if (type.FindMethod(innerMember) == null)
					return .Err(.NotFound);
			default:
			}
		}

		let member = new ExposedMember();
		member.mId = ids.Next();
		member.mPublicName.Set(publicName);
		member.mKind = kind;
		member.mValueKind = valueKind;
		member.mInnerTarget = innerTarget;
		member.mInnerMember = mStrings.Intern(innerMember);
		member.bWritable = writable;
		mStack.Execute(new AddExposedCommand(mSession, member));
		return .Ok(member.mId);
	}

	// How many saved instance values and bindings use the member (across the whole project).
	public int CountUses(ExposedMember member)
	{
		int count = 0;
		let definitions = scope List<CompositionDefinition>();
		mRegistry.GetAll(definitions);
		let instances = scope List<StableId>();
		for (let definition in definitions)
		{
			if (definition.mRoot == null)
				continue;
			let index = DefinitionIndex.Build(definition.mRoot);
			let widgets = scope List<WidgetNodeData>();
			index.GetWidgets(definition.mRoot, widgets);
			delete index;
			for (let widget in widgets)
			{
				if (!widget.mIsInstance || widget.mSourceDefinition != mSession.mDefinition.mId)
					continue;
				instances.Add(widget.mId);
				for (let assignment in widget.mProperties)
				{
					if (assignment.mName == member.mPublicName)
						count++;
				}
			}
			let bindings = scope List<(BindingDescriptor binding, StableId owner)>();
			BindingScanner.Collect(definition.mRoot, bindings);
			for (let entry in bindings)
			{
				if (entry.binding.mSource.mKind == .WidgetProperty && instances.Contains(entry.binding.mSource.mTarget) && entry.binding.mSource.mMember == member.mPublicName)
					count++;
			}
		}
		return count;
	}

	public EditError Unexpose(StableId memberId, bool force = false)
	{
		for (let member in mSession.mDefinition.mExposed)
		{
			if (member.mId != memberId)
				continue;
			if (!force && CountUses(member) > 0)
				return .Blocked;
			mStack.Execute(new RemoveExposedCommand(mSession, member));
			return .None;
		}
		return .NotFound;
	}

	public EditError Rename(StableId memberId, StringView newName)
	{
		if (newName.IsEmpty)
			return .InvalidTarget;
		for (let member in mSession.mDefinition.mExposed)
		{
			if (member.mId != memberId)
				continue;
			if (member.mPublicName == newName)
				return .None;
			if (mSession.mDefinition.FindExposed(newName, member.mKind) != null)
				return .Duplicate;
			mStack.Execute(new RenameExposedCommand(mSession, mRegistry, member, newName, mStrings.Intern(newName)));
			return .None;
		}
		return .NotFound;
	}
}
