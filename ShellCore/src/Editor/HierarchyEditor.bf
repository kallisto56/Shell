namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

// Editing operations for the visual content of one widget skin: layers and element structure. Every change is a command on the
// CommandStack (undo / redo complete) and bumps the definition's revision (instances update). Operations that would break the widget are
// refused with an EditError and change nothing:
//
//   * the Content layer cannot be removed; Underlay must stay before Content and Overlay after it (widget behavior and the child
//     widget draw position depend on that)
//   * essential elements (and anything containing one) cannot be deleted; the skin root cannot be deleted or moved
//   * an element cannot be moved below itself
//   * moving an element between layers never changes its owner; moving it to another owner never changes its layer assignment
// Layers keep order values around the Content layer: ... -200, -100 | Content 0 | 100, 200 ... (renumbered after every layer change).
class HierarchyEditor
{
	DefinitionEditSession mSession;
	ElementTreeData mTree;
	CommandStack mStack;
	IdGenerator mIds;

	public this(DefinitionEditSession session, ElementTreeData tree, CommandStack stack, IdGenerator ids)
	{
		mSession = session;
		mTree = tree;
		mStack = stack;
		mIds = ids;
	}

	// ---- layers ----

	LayerDefinition FindLayer(StableId id)
	{
		for (let layer in mTree.mLayers)
		{
			if (layer.mId == id)
				return layer;
		}
		return null;
	}

	LayerDefinition Content()
	{
		for (let layer in mTree.mLayers)
		{
			if (layer.mRole == .Content)
				return layer;
		}
		return null;
	}

	void SortedLayers(List<LayerDefinition> output)
	{
		output.AddRange(mTree.mLayers);
		output.Sort(scope (a, b) => a.mOrder <=> b.mOrder);
	}

	static EditError ValidateRoles(List<LayerDefinition> sequence)
	{
		int content = -1;
		for (int i < sequence.Count)
		{
			if (sequence[i].mRole == .Content)
				content = i;
		}
		if (content < 0)
			return .Essential;
		for (int i < sequence.Count)
		{
			if (sequence[i].mRole == .Underlay && i > content)
				return .RoleOrder;
			if (sequence[i].mRole == .Overlay && i < content)
				return .RoleOrder;
		}
		return .None;
	}

	// Order values for a sequence: Content = 0, layers before it -100 * distance, layers after it +100 * distance.
	ReorderLayersCommand BuildRenumber(List<LayerDefinition> sequence)
	{
		int content = 0;
		for (int i < sequence.Count)
		{
			if (sequence[i].mRole == .Content)
				content = i;
		}
		let command = new ReorderLayersCommand(mSession, mTree);
		for (int i < sequence.Count)
		{
			let wanted = (i - content) * 100;
			if (sequence[i].mOrder != wanted)
				command.Add(sequence[i].mId, sequence[i].mOrder, wanted);
		}
		return command;
	}

	// Adds a custom layer at the given position in the back-to-front sequence (0 = furthest back).
	public Result<StableId, EditError> AddLayer(StringView name, int insertIndex, StableId id = .sNone)
	{
		let sequence = scope List<LayerDefinition>();
		SortedLayers(sequence);

		let layer = new LayerDefinition();
		layer.mId = id.mIsValid ? id : mIds.Next();
		layer.mName.Set(name);
		layer.mRole = .Custom;
		layer.mOrder = int.MaxValue;
		sequence.Insert(Math.Clamp(insertIndex, 0, sequence.Count), layer);

		let error = ValidateRoles(sequence);
		if (error != .None)
		{
			delete layer;
			return .Err(error);
		}

		mStack.BeginGroup("Add layer");
		mStack.Execute(new AddLayerCommand(mSession, mTree, layer));
		let renumber = BuildRenumber(sequence);
		if (renumber.mHasChanges)
			mStack.Execute(renumber);
		else
			delete renumber;
		mStack.EndGroup();
		return .Ok(layer.mId);
	}

	public EditError MoveLayer(StableId id, int newIndex)
	{
		let layer = FindLayer(id);
		if (layer == null)
			return .NotFound;

		let sequence = scope List<LayerDefinition>();
		SortedLayers(sequence);
		sequence.Remove(layer);
		sequence.Insert(Math.Clamp(newIndex, 0, sequence.Count), layer);

		let error = ValidateRoles(sequence);
		if (error != .None)
			return error;

		let renumber = BuildRenumber(sequence);
		if (!renumber.mHasChanges)
		{
			delete renumber;
			return .None;
		}
		mStack.Execute(renumber);
		return .None;
	}

	// Elements of the layer fall back to Content.
	public EditError RemoveLayer(StableId id)
	{
		let layer = FindLayer(id);
		if (layer == null)
			return .NotFound;
		if (layer.bEssential || layer.mRole == .Content)
			return .Essential;

		mStack.BeginGroup("Remove layer");
		mStack.Execute(new RemoveLayerCommand(mSession, mTree, layer, Content().mId));
		let sequence = scope List<LayerDefinition>();
		SortedLayers(sequence);
		let renumber = BuildRenumber(sequence);
		if (renumber.mHasChanges)
			mStack.Execute(renumber);
		else
			delete renumber;
		mStack.EndGroup();
		return .None;
	}

	public EditError RenameLayer(StableId id, StringView name)
	{
		let layer = FindLayer(id);
		if (layer == null)
			return .NotFound;
		if (name.IsEmpty)
			return .InvalidTarget;
		mStack.Execute(new RenameLayerCommand(mSession, layer, name));
		return .None;
	}

	// ---- elements ----

	public EditError SetElementLayer(StableId elementId, StableId layerId)
	{
		let located = ElementQueries.Locate(mTree, elementId);
		if (located case .Err)
			return .NotFound;
		if (layerId.mIsValid && FindLayer(layerId) == null)
			return .NotFound;
		mStack.Execute(new SetElementLayerCommand(mSession, located.Value.mElement, layerId));
		return .None;
	}

	public EditError SetZIndex(StableId elementId, int zIndex)
	{
		let located = ElementQueries.Locate(mTree, elementId);
		if (located case .Err)
			return .NotFound;
		mStack.Execute(new SetZIndexCommand(mSession, located.Value.mElement, zIndex));
		return .None;
	}

	// `index` is the position among the new parent's children after the move.
	public EditError MoveElement(StableId elementId, StableId newParentId, int index)
	{
		let located = ElementQueries.Locate(mTree, elementId);
		let target = ElementQueries.Locate(mTree, newParentId);
		if (located case .Err)
			return .NotFound;
		if (target case .Err)
			return .NotFound;
		let element = located.Value;
		if (element.mParent == null)
			return .InvalidTarget;          // the skin root stays the root
		if (ElementQueries.IsInside(element.mElement, target.Value.mElement))
			return .Cycle;
		mStack.Execute(new MoveElementCommand(mSession, element.mElement, element.mParent, element.mIndex, target.Value.mElement, index));
		return .None;
	}

	public EditError DeleteElement(StableId elementId)
	{
		let located = ElementQueries.Locate(mTree, elementId);
		if (located case .Err)
			return .NotFound;
		let element = located.Value;
		if (element.mParent == null)
			return .InvalidTarget;
		if (ElementQueries.ContainsEssential(element.mElement))
			return .Essential;
		mStack.Execute(new DeleteElementCommand(mSession, element.mElement, element.mParent, element.mIndex));
		return .None;
	}

	// Takes ownership of `node` (deleted if the operation is refused).
	public EditError CreateElement(StableId parentId, ElementNodeData node, int index)
	{
		let parent = ElementQueries.Locate(mTree, parentId);
		if (parent case .Err)
		{
			delete node;
			return .NotFound;
		}
		if (ElementQueries.Locate(mTree, node.mId) case .Ok)
		{
			delete node;
			return .Duplicate;
		}
		mStack.Execute(new InsertElementCommand(mSession, node, parent.Value.mElement, index));
		return .None;
	}
}
