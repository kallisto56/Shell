namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Elements;
using Shell.Widgets;
using Shell.Composition;
using Shell.Platform;

// Builds live widget trees from saved compositions (WidgetNodeData).
//
//   * primitive nodes are created by the WidgetFactory from their type name, get their saved property values, bindings and skin
//     (through the ElementInstantiator), and their children
//   * instance nodes become UserWidget instances (UserWidgetHost)
// Every object gets the id StableId.Combine(scope, node id) when a scope is given (inside a UserWidget instance), the saved id otherwise.
// Unknown widget types do not abort the load: a plain container takes their place and the problem is reported.
class CompositionInstantiator
{
	RuntimeContext mContext;
	WidgetFactory mFactory;
	BindingSystem mBindings;
	ElementInstantiator mElements;
	UserWidgetHost mHost;
	HashSet<String> mReported = new .() ~ DeleteContainerAndItems!(_);

	public this(RuntimeContext context, WidgetFactory factory, BindingSystem bindings, ElementInstantiator elements, UserWidgetHost host)
	{
		mContext = context;
		mFactory = factory;
		mBindings = bindings;
		mElements = elements;
		mHost = host;
		host.mInstantiator = this;
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

	public Widget InstantiateNode(WidgetNodeData node, Widget parent, StableId scopeId, int depth)
	{
		if (node.mIsInstance)
			return mHost.CreateInstance(node, parent, scopeId, depth);

		var widget = mFactory.Create(node.mTypeName);
		if (widget == null)
		{
			ReportOnce("UWD0004", scope $"Unknown widget type '{node.mTypeName}'; a container is created instead.", node.mId);
			widget = mFactory.Create("Container");
		}

		let id = scopeId.mIsValid ? StableId.Combine(scopeId, node.mId) : node.mId;
		widget.Initialize(mContext, id);
		widget.mSkinScope = scopeId;
		widget.mComponentStyle = node.mComponentStyle;
		if (!node.mName.IsEmpty)
			widget.SetProperty(WidgetTypes.sName, Value.FromString(mContext.mStrings.InternTransient(node.mName)));

		let type = widget.GetDescriptor();
		for (let assignment in node.mProperties)
		{
			let property = type.FindProperty(assignment.mName);
			if (property == null)
			{
				ReportOnce("UWD0005", scope $"Widget type '{type.mName}' has no property '{assignment.mName}'.", id);
				continue;
			}
			if (widget.SetProperty(property, assignment.mValue) case .Err(let error))
				ReportOnce("UWD0006", scope $"The property '{assignment.mName}' could not be set: {error}.", id);
		}
		widget.Activate();
		if (parent != null)
			parent.AddChild(widget);

		for (let binding in node.mBindings)
			mBindings.AddWidgetBinding(widget, binding);
		if (node.mSkin != null)
			mElements.ApplySkin(widget, node.mSkin, scopeId);
		if (node.mEventHooks.Count > 0 || node.mBlueprints.Count > 0)
			ReportOnce("UWD0040", "Blueprint attachments and event hooks are loaded and kept, but run only once the Blueprint host exists.", id);

		for (let child in node.mChildren)
			InstantiateNode(child, widget, scopeId, depth);
		return widget;
	}
}
