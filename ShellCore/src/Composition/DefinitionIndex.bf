namespace Shell.Composition;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;

// Lookup of every widget node and element node of one composition by stable id, with their parents. Built on demand from the data
// model (no runtime objects involved), so tools and the instantiator can answer "what is object X inside this definition" cheaply.
// Ids are unique inside a definition; duplicates are collected in mDuplicates for validation.
class DefinitionIndex
{
	public struct Entry
	{
		public WidgetNodeData mWidget;              // set for widget nodes
		public ElementNodeData mElement;            // set for element nodes
		public WidgetNodeData mParentWidget;        // parent widget (widget nodes) or none
		public WidgetNodeData mOwnerWidget;         // widget whose skin contains the element (element nodes)
		public ElementNodeData mParentElement;      // parent element (element nodes) or none for the skin root
	}

	Dictionary<StableId, Entry> mEntries = new .() ~ delete _;
	public List<StableId> mDuplicates = new .() ~ delete _;

	static public DefinitionIndex Build(WidgetNodeData root)
	{
		let index = new DefinitionIndex();
		if (root != null)
			index.AddWidget(root, null);
		return index;
	}

	void Add(StableId id, Entry entry)
	{
		if (mEntries.ContainsKey(id))
		{
			if (!mDuplicates.Contains(id))
				mDuplicates.Add(id);
			return;
		}
		mEntries[id] = entry;
	}

	void AddWidget(WidgetNodeData widget, WidgetNodeData parent)
	{
		Entry entry = default;
		entry.mWidget = widget;
		entry.mParentWidget = parent;
		Add(widget.mId, entry);

		if (widget.mSkin != null && widget.mSkin.mRoot != null)
			AddElement(widget.mSkin.mRoot, widget, null);
		for (let child in widget.mChildren)
			AddWidget(child, widget);
	}

	void AddElement(ElementNodeData element, WidgetNodeData owner, ElementNodeData parent)
	{
		Entry entry = default;
		entry.mElement = element;
		entry.mOwnerWidget = owner;
		entry.mParentElement = parent;
		Add(element.mId, entry);
		for (let child in element.mChildren)
			AddElement(child, owner, element);
	}

	public Result<Entry> Find(StableId id)
	{
		if (mEntries.TryGetValue(id, let entry))
			return .Ok(entry);
		return .Err;
	}

	public bool Contains(StableId id) => mEntries.ContainsKey(id);
	public int mCount => mEntries.Count;

	// Widget nodes in tree order (parents before children).
	public void GetWidgets(WidgetNodeData root, List<WidgetNodeData> output)
	{
		output.Add(root);
		for (let child in root.mChildren)
			GetWidgets(child, output);
	}
}
