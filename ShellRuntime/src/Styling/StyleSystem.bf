namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Styling;
using Shell.Elements;
using Shell.Widgets;
using Shell.Platform;

// Resolves component styles into property contributions. Runs in the Bindings phase.
//
// For every widget the style is: the style assigned to the instance (Widget.mComponentStyle), otherwise the default style of the widget
// type (or of its nearest base type that has one). The rules of the style (base styles first) whose condition matches the current state
// flags (and named state) are sorted by (priority, declaration order); each setter becomes a contribution on its target:
//
//   target  : the widget itself (no target id) or an element of its skin (target id is an authored id; with the skin scope applied)
//   layer   : ComponentStyle for rules without a condition, StateStyle for state dependent rules
//   value   : the literal, or the design token of the active theme
//
// The PropertyStore arbitrates: Default < Theme < ComponentStyle < StateStyle < InstanceOverride (authored values, bindings, overrides)
// < Animation < Blueprint < Solver. A hover rule therefore changes a property only while nothing above it claims it.
//
// Work is incremental: a widget is restyled only when its state flags, its style, the style registry revision, the theme epoch or the
// structure of its skin changed. A restyle first removes all contributions of this system on the widget and its elements, then adds the
// matching ones, so removed rules and states leave no residue. Problems (missing token, property, target) are reported once.
class StyleSystem : IRuntimeSystem, IObjectDestroyListener
{
	public const int cSource = 1;

	class WidgetState
	{
		public WidgetStateFlags mFlags;
		public StableId mStyle;
		public int mThemeEpoch = -1;
		public int mRegistryRevision = -1;
		public int mStructure = -1;
		public bool bStyled;
	}

	RuntimeContext mContext;
	ThemeManager mThemes;
	StyleRegistry mStyles;
	public Handle mRoot;
	public int mOrder = -100;
	public int mRestyled;               // widgets restyled in the last frame

	Dictionary<Handle, WidgetState> mStates = new .() ~ DeleteDictionaryAndValues!(_);
	HashSet<String> mReported = new .() ~ DeleteContainerAndItems!(_);

	public this(RuntimeContext context, ThemeManager themes, StyleRegistry styles)
	{
		mContext = context;
		mThemes = themes;
		mStyles = styles;
		context.AddDestroyListener(this);
	}

	public ~this()
	{
		mContext.RemoveDestroyListener(this);
	}

	public void SetRoot(Widget root)
	{
		mRoot = root.mHandle;
	}

	public UpdatePhase GetPhase() => .Bindings;
	public int GetOrder() => mOrder;

	public void OnObjectDestroying(RuntimeObject object)
	{
		if (mStates.GetAndRemove(object.mHandle) case .Ok(let entry))
			delete entry.value;
	}

	void ReportOnce(StringView code, StringView message, StableId source)
	{
		let key = scope String();
		key.AppendF("{}|{}|{}", code, message, source);
		if (mReported.Contains(key))
			return;
		mReported.Add(new String(key));
		mContext.mDiagnostics.Warning(code, message, source);
	}

	public void Update(FrameContext frame)
	{
		mRestyled = 0;
		let root = mContext.Resolve<Widget>(mRoot);
		if (root != null)
			Visit(root);
	}

	ComponentStyle ResolveStyle(Widget widget)
	{
		if (widget.mComponentStyle.mIsValid)
		{
			let assigned = mStyles.Find(widget.mComponentStyle);
			if (assigned != null)
				return assigned;
			ReportOnce("STY0001", "The component style assigned to this widget does not exist; the default style is used.", widget.mStableId);
		}
		for (var type = widget.GetDescriptor(); type != null; type = type.mBase)
		{
			let style = mStyles.FindForType(type.mName);
			if (style != null)
				return style;
		}
		return null;
	}

	void Visit(Widget widget)
	{
		if (!widget.mIsAlive)
			return;

		WidgetState state = null;
		if (mStates.TryGetValue(widget.mHandle, let existing))
		{
			state = existing;
		}
		else
		{
			state = new WidgetState();
			mStates[widget.mHandle] = state;
		}

		let flags = widget.mStateFlags;
		let style = ResolveStyle(widget);
		let styleId = (style != null) ? style.mId : StableId.sNone;
		let structure = (widget.mElements != null) ? widget.mElements.mStructureVersion : 0;
		if (!state.bStyled || state.mFlags != flags || state.mStyle != styleId || state.mThemeEpoch != mThemes.mEpoch
			|| state.mRegistryRevision != mStyles.mRevision || state.mStructure != structure)
		{
			Apply(widget, style, flags);
			state.mFlags = flags;
			state.mStyle = styleId;
			state.mThemeEpoch = mThemes.mEpoch;
			state.mRegistryRevision = mStyles.mRevision;
			state.mStructure = structure;
			state.bStyled = true;
			mRestyled++;
		}

		for (let child in widget.mChildren)
			Visit(child);
	}

	static void ClearElements(Element element)
	{
		if (element == null)
			return;
		element.mProperties.ClearSource(cSource);
		for (let child in element.mChildren)
			ClearElements(child);
	}

	static bool IsStateDependent(StyleCondition condition)
	{
		return condition.mRequired != .None || condition.mForbidden != .None || !condition.mNamedState.IsEmpty;
	}

	bool Matches(Widget widget, StyleCondition condition, WidgetStateFlags flags)
	{
		if ((flags & condition.mRequired) != condition.mRequired || (flags & condition.mForbidden) != 0)
			return false;
		if (!condition.mNamedState.IsEmpty)
		{
			let property = widget.GetDescriptor().FindProperty(condition.mNamedState);
			if (property == null)
			{
				ReportOnce("STY0002", scope $"A style condition refers to the unknown state '{condition.mNamedState}'.", widget.mStableId);
				return false;
			}
			if (widget.GetProperty(property).AsBool() != condition.mNamedStateValue)
				return false;
		}
		return true;
	}

	void Apply(Widget widget, ComponentStyle style, WidgetStateFlags flags)
	{
		widget.mProperties.ClearSource(cSource);
		if (widget.mElements != null)
			ClearElements(widget.mElements.mRoot);
		if (style == null)
			return;

		let all = scope List<StyleRule>();
		mStyles.CollectRules(style, all);
		let matching = scope List<(StyleRule rule, int index)>();
		for (int i < all.Count)
		{
			if (Matches(widget, all[i].mCondition, flags))
				matching.Add((all[i], i));
		}
		matching.Sort(scope (a, b) => (a.rule.mPriority != b.rule.mPriority) ? (a.rule.mPriority <=> b.rule.mPriority) : (a.index <=> b.index));

		for (int order < matching.Count)
		{
			let rule = matching[order].rule;
			let layer = IsStateDependent(rule.mCondition) ? PropertyLayer.StateStyle : PropertyLayer.ComponentStyle;
			for (let setter in rule.mSetters)
				ApplySetter(widget, setter, layer, order);
		}
	}

	void ApplySetter(Widget widget, StyleSetter setter, PropertyLayer layer, int order)
	{
		PropertyStore store = null;
		TypeDescriptor type = null;
		if (!setter.mTarget.mIsValid)
		{
			store = widget.mProperties;
			type = widget.GetDescriptor();
		}
		else
		{
			let id = widget.mSkinScope.mIsValid ? StableId.Combine(widget.mSkinScope, setter.mTarget) : setter.mTarget;
			let element = mContext.FindByStableId(id) as Element;
			if (element == null || element.mTree != widget.mElements)
			{
				ReportOnce("STY0011", "A style setter targets an element that is not part of this widget's skin.", setter.mTarget);
				return;
			}
			store = element.mProperties;
			type = element.GetDescriptor();
		}

		let property = type.FindProperty(setter.mProperty);
		if (property == null)
		{
			ReportOnce("STY0010", scope $"'{type.mName}' has no property '{setter.mProperty}' to style.", setter.mTarget);
			return;
		}
		if ((property.mFlags & .Styleable) == 0)
		{
			ReportOnce("STY0012", scope $"The property '{setter.mProperty}' cannot be styled.", setter.mTarget);
			return;
		}

		var value = setter.mValue;
		if (!setter.mToken.IsEmpty)
		{
			if (mThemes.GetToken(setter.mToken) case .Ok(let token))
				value = token;
			else
			{
				ReportOnce("STY0013", scope $"The design token '{setter.mToken}' is not defined in the active theme.", widget.mStableId);
				return;
			}
		}
		if (store.SetContribution(property, layer, cSource, value, .Replace, 1, order) case .Err(let error))
			ReportOnce("STY0014", scope $"The style value for '{setter.mProperty}' does not fit the property: {error}.", setter.mTarget);
	}
}
