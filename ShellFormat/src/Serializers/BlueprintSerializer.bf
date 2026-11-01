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

static class BlueprintSerializer
{
	static void WriteVariables(List<BlueprintVariable> variables, NodeWriter w, SerializationContext context)
	{
		if (variables.Count == 0)
			return;
		let group = w.Group("variables");
		for (let variable in variables)
		{
			let node = NodeWriter.AddNode(group, "Variable", variable.mId);
			let vw = scope NodeWriter(node, context);
			vw.Str("Name", variable.mName);
			vw.Enum("Kind", variable.mKind);
			if (!variable.mDefault.mIsNone) vw.Val("Default", variable.mDefault);
			vw.EnumIf("Scope", variable.mScope, VariableScope.Instance);
			vw.Bool("Public", variable.bPublic);
			vw.Bool("ExternallyWritable", variable.bExternallyWritable);
		}
	}

	static void ReadVariables(NodeReader r, List<BlueprintVariable> output)
	{
		let group = r.Group("variables");
		if (group == null)
			return;
		for (let node in group.mNodes)
		{
			let vr = scope NodeReader(node, r.mContext);
			let variable = new BlueprintVariable();
			variable.mId = node.mId;
			vr.StrInto("Name", variable.mName, true);
			variable.mKind = vr.Enum("Kind", ValueKind.None);
			variable.mDefault = vr.Val("Default");
			variable.mScope = vr.Enum("Scope", VariableScope.Instance);
			variable.bPublic = vr.Bool("Public");
			variable.bExternallyWritable = vr.Bool("ExternallyWritable");
			vr.ReportUnknown();
			output.Add(variable);
		}
	}

	static void WriteParameters(List<ParameterDescriptor> parameters, NodeWriter w, StringView groupName, SerializationContext context)
	{
		if (parameters.Count == 0)
			return;
		let group = w.Group(groupName);
		for (let p in parameters)
		{
			let node = NodeWriter.AddNode(group, "Param", .sNone);
			let pw = scope NodeWriter(node, context);
			pw.Str("Name", p.mName);
			pw.Enum("Kind", p.mKind);
			if (!p.mDefault.mIsNone) pw.Val("Default", p.mDefault);
		}
	}

	static void ReadParameters(NodeReader r, StringView groupName, List<ParameterDescriptor> output)
	{
		let group = r.Group(groupName);
		if (group == null)
			return;
		for (let node in group.mNodes)
		{
			let pr = scope NodeReader(node, r.mContext);
			let p = new ParameterDescriptor(pr.Str("Name", true), pr.Enum("Kind", ValueKind.None));
			p.mDefault = pr.Val("Default");
			pr.ReportUnknown();
			output.Add(p);
		}
	}

	static public void Write(BlueprintAsset asset, DocumentNode node, SerializationContext context)
	{
		let w = scope NodeWriter(node, context);
		w.Str("Name", asset.mName);
		w.Int("Revision", asset.mRevision);
		WriteVariables(asset.mVariables, w, context);

		// Public interface
		let iface = asset.mInterface;
		if (iface.mPublicVariables.Count > 0 || iface.mFunctions.Count > 0 || iface.mEvents.Count > 0)
		{
			let group = w.Group("interface");
			let inode = NodeWriter.AddNode(group, "Interface", .sNone);
			let iw = scope NodeWriter(inode, context);
			for (int i < iface.mPublicVariables.Count)
				iw.IdAlways(scope $"var{i}", iface.mPublicVariables[i]);
			if (iface.mFunctions.Count > 0)
			{
				let functions = iw.Group("functions");
				for (let fn in iface.mFunctions)
				{
					let fnode = NodeWriter.AddNode(functions, "Function", fn.mId);
					let fw = scope NodeWriter(fnode, context);
					fw.Str("Name", fn.mName);
					WriteParameters(fn.mInputs, fw, "inputs", context);
					WriteParameters(fn.mOutputs, fw, "outputs", context);
				}
			}
			if (iface.mEvents.Count > 0)
			{
				let events = iw.Group("events");
				for (let ev in iface.mEvents)
				{
					let enode = NodeWriter.AddNode(events, "EventSignature", ev.mId);
					let ew = scope NodeWriter(enode, context);
					ew.Str("Name", ev.mName);
					WriteParameters(ev.mParameters, ew, "parameters", context);
				}
			}
		}

		if (asset.mGraphs.Count > 0)
		{
			let graphs = w.Group("graphs");
			for (let graph in asset.mGraphs)
				WriteGraph(graph, NodeWriter.AddNode(graphs, "Graph", graph.mId), context);
		}
	}

	static void WriteGraph(Graph graph, DocumentNode node, SerializationContext context)
	{
		let w = scope NodeWriter(node, context);
		w.Str("Name", graph.mName);
		w.Enum("Kind", graph.mKind);
		w.Id("Signature", graph.mSignature);
		WriteVariables(graph.mLocals, w, context);

		if (graph.mNodes.Count > 0)
		{
			let nodes = w.Group("nodes");
			for (let gn in graph.mNodes)
			{
				let nn = NodeWriter.AddNode(nodes, "Node", gn.mId);
				let nw = scope NodeWriter(nn, context);
				nw.Enum("Kind", gn.mKind);
				nw.StrIf("TypeName", gn.mTypeName);
				nw.Float("X", gn.mX);
				nw.Float("Y", gn.mY);
				nw.StrIf("Comment", gn.mComment);
				for (let property in gn.mProperties)
					nw.Val(scope $"prop.{property.mName}", property.mValue);
				if (gn.mPins.Count > 0)
				{
					let pins = nw.Group("pins");
					for (let pin in gn.mPins)
					{
						let pn = NodeWriter.AddNode(pins, "Pin", pin.mId);
						let pw = scope NodeWriter(pn, context);
						pw.Str("Name", pin.mName);
						pw.Enum("Direction", pin.mDirection);
						pw.Enum("Category", pin.mCategory);
						if (pin.mCategory == .Data)
						{
							pw.Enum("Type", pin.mKind);
							if (!pin.mDefault.mIsNone) pw.Val("Default", pin.mDefault);
						}
					}
				}
			}
		}

		if (graph.mLinks.Count > 0)
		{
			let links = w.Group("links");
			for (let link in graph.mLinks)
			{
				let ln = NodeWriter.AddNode(links, "Link", link.mId);
				let lw = scope NodeWriter(ln, context);
				lw.IdAlways("FromNode", link.mFromNode);
				lw.IdAlways("FromPin", link.mFromPin);
				lw.IdAlways("ToNode", link.mToNode);
				lw.IdAlways("ToPin", link.mToPin);
			}
		}
	}

	static public BlueprintAsset Read(DocumentNode node, SerializationContext context)
	{
		let r = scope NodeReader(node, context);
		let asset = new BlueprintAsset();
		asset.mId = node.mId;
		r.StrInto("Name", asset.mName);
		asset.mRevision = (uint32)r.Int("Revision");
		ReadVariables(r, asset.mVariables);

		let iface = r.Group("interface");
		if (iface != null && iface.mNodes.Count > 0)
		{
			let ir = scope NodeReader(iface.mNodes[0], context);
			for (var i = 0; ir.Has(scope $"var{i}"); i++)
				asset.mInterface.mPublicVariables.Add(ir.Id(scope $"var{i}"));

			let functions = ir.Group("functions");
			if (functions != null)
			{
				for (let fnode in functions.mNodes)
				{
					let fr = scope NodeReader(fnode, context);
					let fn = new FunctionSignature();
					fn.mId = fnode.mId;
					fr.StrInto("Name", fn.mName, true);
					ReadParameters(fr, "inputs", fn.mInputs);
					ReadParameters(fr, "outputs", fn.mOutputs);
					fr.ReportUnknown();
					asset.mInterface.mFunctions.Add(fn);
				}
			}
			let events = ir.Group("events");
			if (events != null)
			{
				for (let enode in events.mNodes)
				{
					let er = scope NodeReader(enode, context);
					let ev = new EventSignature();
					ev.mId = enode.mId;
					er.StrInto("Name", ev.mName, true);
					ReadParameters(er, "parameters", ev.mParameters);
					er.ReportUnknown();
					asset.mInterface.mEvents.Add(ev);
				}
			}
			ir.ReportUnknown();
		}

		let graphs = r.Group("graphs");
		if (graphs != null)
		{
			for (let gnode in graphs.mNodes)
				asset.mGraphs.Add(ReadGraph(gnode, context));
		}
		r.ReportUnknown();
		return asset;
	}

	static Graph ReadGraph(DocumentNode node, SerializationContext context)
	{
		let r = scope NodeReader(node, context);
		let graph = new Graph();
		graph.mId = node.mId;
		r.StrInto("Name", graph.mName);
		graph.mKind = r.Enum("Kind", GraphKind.EventGraph);
		graph.mSignature = r.Id("Signature");
		ReadVariables(r, graph.mLocals);

		let nodes = r.Group("nodes");
		if (nodes != null)
		{
			for (let nn in nodes.mNodes)
			{
				let nr = scope NodeReader(nn, context);
				let gn = new GraphNode();
				gn.mId = nn.mId;
				gn.mKind = nr.Enum("Kind", NodeKind.Literal);
				nr.StrInto("TypeName", gn.mTypeName);
				gn.mX = (float)nr.Float("X");
				gn.mY = (float)nr.Float("Y");
				nr.StrInto("Comment", gn.mComment);

				let props = scope List<(StringView name, Value value)>();
				nr.CollectPrefixed("prop.", props);
				for (let item in props)
				{
					NodeProperty property = default;
					property.mName = item.name;
					property.mValue = item.value;
					gn.mProperties.Add(property);
				}

				let pins = nr.Group("pins");
				if (pins != null)
				{
					for (let pn in pins.mNodes)
					{
						let pr = scope NodeReader(pn, context);
						let pin = new Pin();
						pin.mId = pn.mId;
						pr.StrInto("Name", pin.mName, true);
						pin.mDirection = pr.Enum("Direction", PinDirection.In);
						pin.mCategory = pr.Enum("Category", PinCategory.Data);
						pin.mKind = pr.Enum("Type", ValueKind.None);
						pin.mDefault = pr.Val("Default");
						pr.ReportUnknown();
						gn.mPins.Add(pin);
					}
				}
				nr.ReportUnknown();
				graph.mNodes.Add(gn);
			}
		}

		let links = r.Group("links");
		if (links != null)
		{
			for (let ln in links.mNodes)
			{
				let lr = scope NodeReader(ln, context);
				let link = new GraphLink();
				link.mId = ln.mId;
				link.mFromNode = lr.Id("FromNode", true);
				link.mFromPin = lr.Id("FromPin", true);
				link.mToNode = lr.Id("ToNode", true);
				link.mToPin = lr.Id("ToPin", true);
				lr.ReportUnknown();
				graph.mLinks.Add(link);
			}
		}
		r.ReportUnknown();
		return graph;
	}
}
