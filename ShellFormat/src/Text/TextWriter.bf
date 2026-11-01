namespace Shell.Format;

using System;
using System.Collections;
using Shell.Core;
using Shell.Serialization;

// Writes a Document as text. Deterministic: the output depends only on the document content (fields and groups in the
// order they are stored), uses LF line ends, tabs for indentation and no trailing spaces.
static class TextWriter
{
	// Returns false (and reports) if the document contains a value that cannot be saved.
	static public bool Write(Document document, String output, DiagnosticSink sink)
	{
		output.Append(FormatInfo.cMagic);
		output.Append(' ');
		document.mVersion.ToString(output);
		output.Append('\n');
		return WriteNode(document.mRoot, 0, output, sink);
	}

	static void Indent(int depth, String output)
	{
		for (int i < depth)
			output.Append('\t');
	}

	static bool WriteNode(DocumentNode node, int depth, String output, DiagnosticSink sink)
	{
		bool bOk = true;
		Indent(depth, output);
		output.Append(node.mType);
		output.Append(' ');
		if (node.mId.mIsValid) node.mId.ToString(output);
		else output.Append('-');
		output.Append('\n');
		Indent(depth, output);
		output.Append("{\n");

		for (let field in node.mFields)
		{
			Indent(depth + 1, output);
			output.Append(field.mName);
			output.Append(':');
			output.Append(ValueCodec.KindName(field.mValue.mKind));
			output.Append(" = ");
			if (!ValueCodec.Write(field.mValue, output))
			{
				sink.Error("SER0301", scope $"Field '{field.mName}' of '{node.mType}' holds a runtime-only value and cannot be saved.", node.mId);
				bOk = false;
			}
			output.Append('\n');
		}

		for (let group in node.mGroups)
		{
			Indent(depth + 1, output);
			output.Append(group.mName);
			output.Append("[\n");
			for (let child in group.mNodes)
			{
				if (!WriteNode(child, depth + 2, output, sink))
					bOk = false;
			}
			Indent(depth + 1, output);
			output.Append("]\n");
		}

		Indent(depth, output);
		output.Append("}\n");
		return bOk;
	}
}
