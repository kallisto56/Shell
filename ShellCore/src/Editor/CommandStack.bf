namespace Shell.Editor;

using System;
using System.Collections;

class CommandStack
{
	class Group : ICommand
	{
		public String mName = new .() ~ delete _;
		public List<ICommand> mCommands = new .() ~ DeleteContainerAndItems!(_);

		public StringView GetName() => mName;
		public void Do() { for (let c in mCommands) c.Do(); }
		public void Undo() { for (var i = mCommands.Count - 1; i >= 0; i--) mCommands[i].Undo(); }
		public bool TryMerge(ICommand next) => false;
	}

	List<ICommand> mUndo = new .() ~ DeleteContainerAndItems!(_);
	List<ICommand> mRedo = new .() ~ DeleteContainerAndItems!(_);
	Group mOpenGroup;
	int mSavedDepth;                    // undo depth at the last save; -1 when the saved state is unreachable

	public bool mCanUndo => mUndo.Count > 0;
	public bool mCanRedo => mRedo.Count > 0;
	public bool mIsDirty => mUndo.Count != mSavedDepth;

	public void MarkSaved()
	{
		mSavedDepth = mUndo.Count;
	}

	// Takes ownership of the command and executes it.
	public void Execute(ICommand command)
	{
		command.Do();

		if (mOpenGroup != null)
		{
			mOpenGroup.mCommands.Add(command);
			return;
		}

		mRedo.ClearAndDeleteItems();
		if (mSavedDepth > mUndo.Count)
			mSavedDepth = -1;

		if (mUndo.Count > 0 && mUndo.Back.TryMerge(command))
		{
			delete command;
			return;
		}
		mUndo.Add(command);
	}

	// Several commands that undo as one step ("Extract UserWidget", "Delete selection").
	public void BeginGroup(StringView name)
	{
		Runtime.Assert(mOpenGroup == null, "Nested command groups are not supported");
		mOpenGroup = new Group();
		mOpenGroup.mName.Set(name);
	}

	public void EndGroup()
	{
		let group = mOpenGroup;
		mOpenGroup = null;
		if (group.mCommands.Count == 0)
		{
			delete group;
			return;
		}
		mRedo.ClearAndDeleteItems();
		mUndo.Add(group);
	}

	public void Undo()
	{
		if (mUndo.Count == 0)
			return;
		let command = mUndo.PopBack();
		command.Undo();
		mRedo.Add(command);
	}

	public void Redo()
	{
		if (mRedo.Count == 0)
			return;
		let command = mRedo.PopBack();
		command.Do();
		mUndo.Add(command);
	}
}
