namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

// Renames the public name of an exposed member and rewrites everything that referred to the old name: saved property values of the
// instances and bindings that read the instance's property. Instances therefore keep their values and bindings keep working.
class RenameExposedCommand : DefinitionCommand
{
	ExposedMember mMember;
	String mOldName = new .() ~ delete _;
	String mNewName = new .() ~ delete _;
	StringView mOldInterned;
	StringView mNewInterned;
	List<(WidgetNodeData node, int index)> mAssignments = new .() ~ delete _;
	List<BindingDescriptor> mBindings = new .() ~ delete _;

	public this(DefinitionEditSession session, CompositionRegistry registry, ExposedMember member, StringView newName, StringView newInterned) : base(session, "Rename exposed member")
	{
		mMember = member;
		mOldName.Set(member.mPublicName);
		mNewName.Set(newName);
		mNewInterned = newInterned;

		// Find every reference in the project: instance nodes of this definition and bindings that read their property.
		let definitions = scope List<CompositionDefinition>();
		registry.GetAll(definitions);
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
				if (!widget.mIsInstance || widget.mSourceDefinition != session.mDefinition.mId)
					continue;
				instances.Add(widget.mId);
				for (int i < widget.mProperties.Count)
				{
					if (widget.mProperties[i].mName == mOldName)
						mAssignments.Add((widget, i));
				}
			}
			let bindings = scope List<(BindingDescriptor binding, StableId owner)>();
			BindingScanner.Collect(definition.mRoot, bindings);
			for (let entry in bindings)
			{
				if (entry.binding.mSource.mKind == .WidgetProperty && instances.Contains(entry.binding.mSource.mTarget) && entry.binding.mSource.mMember == mOldName)
				{
					mBindings.Add(entry.binding);
					mOldInterned = entry.binding.mSource.mMember;
				}
			}
		}
	}

	void Set(bool bNew)
	{
		let name = bNew ? StringView(mNewName) : StringView(mOldName);
		mMember.mPublicName.Set(name);
		for (let entry in mAssignments)
		{
			var assignment = entry.node.mProperties[entry.index];
			assignment.mName = bNew ? mNewInterned : mOldInterned;
			entry.node.mProperties[entry.index] = assignment;
		}
		for (let binding in mBindings)
			binding.mSource.mMember = bNew ? mNewInterned : mOldInterned;
	}

	protected override void Apply() => Set(true);
	protected override void Revert() => Set(false);
}
