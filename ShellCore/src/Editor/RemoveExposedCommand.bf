namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

class RemoveExposedCommand : DefinitionCommand
{
	ExposedMember mMember;
	int mIndex;
	bool bRemoved;

	public this(DefinitionEditSession session, ExposedMember member) : base(session, "Hide member")
	{
		mMember = member;
	}

	public ~this()
	{
		if (bRemoved)
			delete mMember;
	}

	protected override void Apply()
	{
		mIndex = mSession.mDefinition.mExposed.IndexOf(mMember);
		mSession.mDefinition.mExposed.Remove(mMember);
		bRemoved = true;
	}

	protected override void Revert()
	{
		let list = mSession.mDefinition.mExposed;
		list.Insert(Math.Clamp(mIndex, 0, list.Count), mMember);
		bRemoved = false;
	}
}
