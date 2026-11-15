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

static class BindingSerializer
{
	static public void WriteList(List<BindingDescriptor> list, NodeWriter parent, StringView groupName = "bindings")
	{
		if (list.Count == 0)
			return;
		let group = parent.Group(groupName);
		for (let binding in list)
			Write(binding, NodeWriter.AddNode(group, "Binding", binding.mId), parent.mContext);
	}

	static public void Write(BindingDescriptor binding, DocumentNode node, SerializationContext context)
	{
		let w = scope NodeWriter(node, context);
		w.Str("Target", binding.mTargetProperty);
		w.EnumIf("Mode", binding.mMode, BindingMode.OneWay);
		w.Enum("SourceKind", binding.mSource.mKind);
		w.Id("SourceTarget", binding.mSource.mTarget);
		w.StrIf("SourceMember", binding.mSource.mMember);
		if (binding.mSource.mKind == .Constant)
			w.Val("SourceConstant", binding.mSource.mConstant);
		if (binding.mSource.mKind == .TimeBuiltin)
			w.Enum("SourceTime", binding.mSource.mTime);
		if (!binding.mFallback.mIsNone)
			w.Val("Fallback", binding.mFallback);

		if (binding.mConverters.Count > 0)
		{
			let group = w.Group("converters");
			for (let step in binding.mConverters)
			{
				let child = NodeWriter.AddNode(group, "Converter", .sNone);
				let cw = scope NodeWriter(child, context);
				cw.Enum("Kind", step.mKind);
				if (!step.mArg0.mIsNone) cw.Val("Arg0", step.mArg0);
				if (!step.mArg1.mIsNone) cw.Val("Arg1", step.mArg1);
			}
		}
	}

	static public BindingDescriptor Read(DocumentNode node, SerializationContext context)
	{
		let r = scope NodeReader(node, context);
		let binding = new BindingDescriptor();
		binding.mId = node.mId;
		binding.mTargetProperty = r.Str("Target", true);
		binding.mMode = r.Enum("Mode", BindingMode.OneWay);
		binding.mSource.mKind = r.Enum("SourceKind", BindingSourceKind.Constant);
		binding.mSource.mTarget = r.Id("SourceTarget");
		binding.mSource.mMember = r.Str("SourceMember");
		binding.mSource.mConstant = r.Val("SourceConstant");
		binding.mSource.mTime = r.Enum("SourceTime", TimeBuiltin.Time);
		binding.mFallback = r.Val("Fallback");

		let group = r.Group("converters");
		if (group != null)
		{
			for (let child in group.mNodes)
			{
				let cr = scope NodeReader(child, context);
				ConverterStep step = default;
				step.mKind = cr.Enum("Kind", ConverterKind.Not);
				step.mArg0 = cr.Val("Arg0");
				step.mArg1 = cr.Val("Arg1");
				cr.ReportUnknown();
				binding.mConverters.Add(step);
			}
		}
		r.ReportUnknown();
		return binding;
	}

	static public void ReadList(NodeReader parent, StringView groupName, List<BindingDescriptor> output)
	{
		let group = parent.Group(groupName);
		if (group == null)
			return;
		for (let node in group.mNodes)
			output.Add(Read(node, parent.mContext));
	}
}
