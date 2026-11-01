namespace Shell.Format;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Elements;
using Shell.Blueprints;
using Shell.Composition;
using Shell.Animation;
using Shell.Styling;
using Shell.Serialization;
using Shell.Platform;
using Shell.Widgets;

static class StyleSerializer
{
	// ---- Global variables ----
	static public void WriteGlobal(GlobalVariableDefinition global, DocumentNode node, SerializationContext context)
	{
		let w = scope NodeWriter(node, context);
		w.Str("Name", global.mName);
		w.Enum("Kind", global.mKind);
		if (!global.mInitial.mIsNone) w.Val("Initial", global.mInitial);
		w.Bool("Persistent", global.bPersistent);
		w.StrIf("Description", global.mDescription);
	}

	static public GlobalVariableDefinition ReadGlobal(DocumentNode node, SerializationContext context)
	{
		let r = scope NodeReader(node, context);
		let global = new GlobalVariableDefinition();
		global.mId = node.mId;
		r.StrInto("Name", global.mName, true);
		global.mKind = r.Enum("Kind", ValueKind.None);
		global.mInitial = r.Val("Initial");
		global.bPersistent = r.Bool("Persistent");
		r.StrInto("Description", global.mDescription);
		r.ReportUnknown();
		return global;
	}

	// ---- Themes ----
	static public void WriteTheme(Theme theme, DocumentNode node, SerializationContext context)
	{
		let w = scope NodeWriter(node, context);
		w.Str("Name", theme.mName);
		w.Id("Parent", theme.mParent);
		if (theme.mTokens.Count > 0)
		{
			let group = w.Group("tokens");
			for (let token in theme.mTokens)
			{
				let tn = NodeWriter.AddNode(group, "Token", token.mId);
				let tw = scope NodeWriter(tn, context);
				tw.Str("Name", token.mName);
				tw.Enum("Kind", token.mKind);
				if (!token.mValue.mIsNone) tw.Val("Value", token.mValue);
				tw.StrIf("Alias", token.mAlias);
			}
		}
	}

	static public Theme ReadTheme(DocumentNode node, SerializationContext context)
	{
		let r = scope NodeReader(node, context);
		let theme = new Theme();
		theme.mId = node.mId;
		r.StrInto("Name", theme.mName);
		theme.mParent = r.Id("Parent");
		let tokens = r.Group("tokens");
		if (tokens != null)
		{
			for (let tn in tokens.mNodes)
			{
				let tr = scope NodeReader(tn, context);
				let token = new DesignToken();
				token.mId = tn.mId;
				tr.StrInto("Name", token.mName, true);
				token.mKind = tr.Enum("Kind", ValueKind.None);
				token.mValue = tr.Val("Value");
				tr.StrInto("Alias", token.mAlias);
				tr.ReportUnknown();
				theme.mTokens.Add(token);
			}
		}
		r.ReportUnknown();
		return theme;
	}

	// ---- Component styles ----
	static public void WriteStyle(ComponentStyle style, DocumentNode node, SerializationContext context)
	{
		let w = scope NodeWriter(node, context);
		w.Str("Name", style.mName);
		w.StrIf("WidgetType", style.mWidgetType);
		w.Id("Base", style.mBaseStyle);
		if (style.mRules.Count > 0)
		{
			let group = w.Group("rules");
			for (let rule in style.mRules)
			{
				let rn = NodeWriter.AddNode(group, "Rule", rule.mId);
				let rw = scope NodeWriter(rn, context);
				rw.Int("Priority", rule.mPriority);
				rw.Flags("Required", (uint32)rule.mCondition.mRequired);
				rw.Flags("Forbidden", (uint32)rule.mCondition.mForbidden);
				rw.StrIf("NamedState", rule.mCondition.mNamedState);
				if (!rule.mCondition.mNamedState.IsEmpty)
					rw.BoolAlways("NamedStateValue", rule.mCondition.mNamedStateValue);
				if (rule.mSetters.Count > 0)
				{
					let setters = rw.Group("setters");
					for (let setter in rule.mSetters)
					{
						let sn = NodeWriter.AddNode(setters, "Setter", .sNone);
						let sw = scope NodeWriter(sn, context);
						sw.Id("Target", setter.mTarget);
						sw.Str("Property", setter.mProperty);
						if (!setter.mValue.mIsNone) sw.Val("Value", setter.mValue);
						sw.StrIf("Token", setter.mToken);
					}
				}
			}
		}
	}

	static public ComponentStyle ReadStyle(DocumentNode node, SerializationContext context)
	{
		let r = scope NodeReader(node, context);
		let style = new ComponentStyle();
		style.mId = node.mId;
		r.StrInto("Name", style.mName);
		style.mWidgetType = r.Str("WidgetType");
		style.mBaseStyle = r.Id("Base");
		let rules = r.Group("rules");
		if (rules != null)
		{
			for (let rn in rules.mNodes)
			{
				let rr = scope NodeReader(rn, context);
				let rule = new StyleRule();
				rule.mId = rn.mId;
				rule.mPriority = (int)rr.Int("Priority");
				rule.mCondition.mRequired = (WidgetStateFlags)rr.Flags("Required");
				rule.mCondition.mForbidden = (WidgetStateFlags)rr.Flags("Forbidden");
				rule.mCondition.mNamedState = rr.Str("NamedState");
				rule.mCondition.mNamedStateValue = rr.Bool("NamedStateValue");
				let setters = rr.Group("setters");
				if (setters != null)
				{
					for (let sn in setters.mNodes)
					{
						let sr = scope NodeReader(sn, context);
						StyleSetter setter = default;
						setter.mTarget = sr.Id("Target");
						setter.mProperty = sr.Str("Property", true);
						setter.mValue = sr.Val("Value");
						setter.mToken = sr.Str("Token");
						sr.ReportUnknown();
						rule.mSetters.Add(setter);
					}
				}
				rr.ReportUnknown();
				style.mRules.Add(rule);
			}
		}
		r.ReportUnknown();
		return style;
	}
}
