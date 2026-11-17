namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

class AddExposedCommand : DefinitionCommand
{
	ExposedMember mMember;
	bool bAdded;

	public this(DefinitionEditSession session, ExposedMember member) : base(session, "Expose member")
	{
		mMember = member;
	}

	public ~this()
	{
		if (!bAdded)
			delete mMember;
	}

	protected override void Apply()
	{
		mSession.mDefinition.mExposed.Add(mMember);
		bAdded = true;
	}

	protected override void Revert()
	{
		mSession.mDefinition.mExposed.Remove(mMember);
		bAdded = false;
	}
}
