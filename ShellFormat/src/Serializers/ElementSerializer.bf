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

static class ElementSerializer
{
	static public void WriteTree(ElementTreeData tree, DocumentNode node, SerializationContext context)
	{
		let w = scope NodeWriter(node, context);
		if (tree.mLayers.Count > 0)
		{
			let group = w.Group("layers");
			for (let layer in tree.mLayers)
			{
				let child = NodeWriter.AddNode(group, "Layer", layer.mId);
				let lw = scope NodeWriter(child, context);
				lw.Str("Name", layer.mName);
				lw.Enum("Role", layer.mRole);
				lw.Int("Order", layer.mOrder);
				lw.Bool("Essential", layer.bEssential);
			}
		}
		if (tree.mRoot != null)
		{
			let group = w.Group("root");
			WriteElement(tree.mRoot, NodeWriter.AddNode(group, "Element", tree.mRoot.mId), context);
		}
	}

	static public ElementTreeData ReadTree(DocumentNode node, SerializationContext context)
	{
		let r = scope NodeReader(node, context);
		let tree = new ElementTreeData();

		let layers = r.Group("layers");
		if (layers != null)
		{
			for (let child in layers.mNodes)
			{
				let lr = scope NodeReader(child, context);
				let layer = new LayerDefinition();
				layer.mId = child.mId;
				lr.StrInto("Name", layer.mName, true);
				layer.mRole = lr.Enum("Role", LayerRole.Custom);
				layer.mOrder = (int)lr.Int("Order");
				layer.bEssential = lr.Bool("Essential");
				lr.ReportUnknown();
				tree.mLayers.Add(layer);
			}
		}

		let root = r.Group("root");
		if (root != null && root.mNodes.Count > 0)
			tree.mRoot = ReadElement(root.mNodes[0], context);
		r.ReportUnknown();
		return tree;
	}

	static void WriteElement(ElementNodeData element, DocumentNode node, SerializationContext context)
	{
		let w = scope NodeWriter(node, context);
		w.Enum("Kind", element.mKind);
		w.StrIf("Type", element.mTypeName);
		w.StrIf("Name", element.mName);
		w.Id("Layer", element.mLayer);
		w.Int("ZIndex", element.mZIndex);
		w.EnumIf("Composite", element.mComposite, CompositeMode.None);
		PropertyValues.Write(element.mProperties, w);
		BindingSerializer.WriteList(element.mBindings, w);

		if (element.mVisibleWhen != null)
		{
			let group = w.Group("visibleWhen");
			BindingSerializer.Write(element.mVisibleWhen, NodeWriter.AddNode(group, "Binding", element.mVisibleWhen.mId), context);
		}

		if (element.mEffects.Count > 0)
		{
			let group = w.Group("effects");
			for (let effect in element.mEffects)
			{
				let child = NodeWriter.AddNode(group, "Effect", effect.mId);
				let ew = scope NodeWriter(child, context);
				ew.Enum("Kind", effect.mKind);
				ew.StrIf("CustomName", effect.mCustomName);
				ew.Bool("Enabled", effect.bEnabled, true);
				for (int i < effect.mParameters.Count)
					ew.Val(scope $"p{i}", effect.mParameters[i]);
			}
		}

		if (element.mChildren.Count > 0)
		{
			let group = w.Group("children");
			for (let child in element.mChildren)
				WriteElement(child, NodeWriter.AddNode(group, "Element", child.mId), context);
		}
	}

	static ElementNodeData ReadElement(DocumentNode node, SerializationContext context)
	{
		let r = scope NodeReader(node, context);
		let element = new ElementNodeData();
		element.mId = node.mId;
		element.mKind = r.Enum("Kind", ElementKind.Container);
		element.mTypeName = r.Str("Type");
		r.StrInto("Name", element.mName);
		element.mLayer = r.Id("Layer");
		element.mZIndex = (int)r.Int("ZIndex");
		element.mComposite = r.Enum("Composite", CompositeMode.None);
		PropertyValues.Read(r, element.mProperties);
		BindingSerializer.ReadList(r, "bindings", element.mBindings);

		let visible = r.Group("visibleWhen");
		if (visible != null && visible.mNodes.Count > 0)
			element.mVisibleWhen = BindingSerializer.Read(visible.mNodes[0], context);

		let effects = r.Group("effects");
		if (effects != null)
		{
			for (let child in effects.mNodes)
			{
				let er = scope NodeReader(child, context);
				let effect = new EffectDescriptor();
				effect.mId = child.mId;
				effect.mKind = er.Enum("Kind", EffectKind.Custom);
				effect.mCustomName = er.Str("CustomName");
				effect.bEnabled = er.Bool("Enabled", true);
				for (var i = 0; er.Has(scope $"p{i}"); i++)
					effect.mParameters.Add(er.Val(scope $"p{i}"));
				er.ReportUnknown();
				element.mEffects.Add(effect);
			}
		}

		let children = r.Group("children");
		if (children != null)
		{
			for (let child in children.mNodes)
				element.mChildren.Add(ReadElement(child, context));
		}
		r.ReportUnknown();
		return element;
	}
}
