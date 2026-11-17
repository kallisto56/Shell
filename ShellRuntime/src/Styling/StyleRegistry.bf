namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Styling;

// Component styles of a project by id and by widget type. mRevision changes whenever a style is added or edited, which makes the style
// system restyle the widgets that use it.
class StyleRegistry
{
	Dictionary<StableId, ComponentStyle> mById = new .() ~ delete _;      // not owned
	List<ComponentStyle> mOrdered = new .() ~ delete _;
	public int mRevision;

	public void Add(ComponentStyle style)
	{
		mById[style.mId] = style;
		mOrdered.Add(style);
		mRevision++;
	}

	public ComponentStyle Find(StableId id)
	{
		if (mById.TryGetValue(id, let style))
			return style;
		return null;
	}

	// First registered style for the widget type name (the default style of that type).
	public ComponentStyle FindForType(StringView widgetType)
	{
		for (let style in mOrdered)
		{
			if (style.mWidgetType == widgetType)
				return style;
		}
		return null;
	}

	// Call after a style was edited.
	public void NotifyEdited()
	{
		mRevision++;
	}

	// Rules of the style and of its base styles, base first, each in declaration order. A base chain that loops is cut.
	public void CollectRules(ComponentStyle style, List<StyleRule> output)
	{
		let chain = scope List<ComponentStyle>();
		var current = style;
		while (current != null && !chain.Contains(current) && chain.Count < 16)
		{
			chain.Add(current);
			current = Find(current.mBaseStyle);
		}
		for (var i = chain.Count - 1; i >= 0; i--)
			output.AddRange(chain[i].mRules);
	}
}
