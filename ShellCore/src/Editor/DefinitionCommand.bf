namespace Shell.Editor;

using System;
using Shell.Core;

// Base of the editing commands: Apply / Revert change the model, Do / Undo add the revision bump.
abstract class DefinitionCommand : ICommand
{
	protected DefinitionEditSession mSession;
	protected String mName = new .() ~ delete _;

	public this(DefinitionEditSession session, StringView name)
	{
		mSession = session;
		mName.Set(name);
	}

	public StringView GetName() => mName;

	public void Do()
	{
		Apply();
		mSession.Touch();
	}

	public void Undo()
	{
		Revert();
		mSession.Touch();
	}

	public virtual bool TryMerge(ICommand next) => false;

	protected abstract void Apply();
	protected abstract void Revert();
}
