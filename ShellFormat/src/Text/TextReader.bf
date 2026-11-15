namespace Shell.Format;

using System;
using System.Collections;
using Shell.Core;
using Shell.Serialization;

// Parses the saved text format into a generic Document.
//
//   juno-shell 1.0
//   Type 0123456789abcdef            <- node header: type name and stable id ('-' = no id)
//   {
//   	Name:string = "text"           <- field: name ':' kind '=' payload
//   	children[                      <- group of child nodes
//   		Type ...
//   	]
//   }
//
// Errors are reported with a stable code, the line number and what was expected; parsing stops at the first error.
class TextReader
{
	const int cMaxDepth = 64;

	DiagnosticSink mSink;
	Document mDocument;
	List<StringView> mLines = new .() ~ delete _;
	List<int> mLineNumbers = new .() ~ delete _;
	int mIndex;
	bool bFailed;

	static public Result<Document> Parse(StringView text, DiagnosticSink sink)
	{
		let reader = scope TextReader();
		reader.mSink = sink;
		return reader.Run(text);
	}

	void Fail(StringView code, StringView message, int lineNumber = -1)
	{
		if (bFailed)
			return;
		bFailed = true;
		let line = (lineNumber >= 0) ? lineNumber : ((mIndex < mLineNumbers.Count) ? mLineNumbers[mIndex] : mLineNumbers.Count);
		mSink.Error(code, scope $"Line {line}: {message}");
	}

	// Next non-empty line (trimmed) or false at the end.
	bool Next(out StringView line)
	{
		line = default;
		if (mIndex >= mLines.Count)
			return false;
		line = mLines[mIndex];
		mIndex++;
		return true;
	}

	Result<Document> Run(StringView text)
	{
		var number = 0;
		for (var raw in text.Split('\n'))
		{
			number++;
			raw.Trim();           // also removes a trailing '\r'
			if (raw.IsEmpty)
				continue;
			mLines.Add(raw);
			mLineNumbers.Add(number);
		}

		mDocument = new Document();
		if (!ParseHeader() || bFailed)
		{
			delete mDocument;
			return .Err;
		}

		mDocument.mRoot = ParseNode(0);
		if (mDocument.mRoot == null || bFailed)
		{
			delete mDocument;
			return .Err;
		}
		if (mIndex < mLines.Count)
		{
			Fail("SER0110", "unexpected content after the root node");
			delete mDocument;
			return .Err;
		}
		return .Ok(mDocument);
	}

	bool ParseHeader()
	{
		if (!Next(var line))
		{
			Fail("SER0101", "the file is empty", 1);
			return false;
		}

		let parts = scope List<StringView>();
		for (let part in line.Split(' ', .RemoveEmptyEntries))
			parts.Add(part);
		if (parts.Count != 2 || parts[0] != FormatInfo.cMagic)
		{
			Fail("SER0101", scope $"expected the header '{FormatInfo.cMagic} <major>.<minor>'", mLineNumbers[mIndex - 1]);
			return false;
		}

		let dot = parts[1].IndexOf('.');
		var a = (NumberFormat.ParseInt(parts[1].Substring(0, dot)) case .Ok(let major));
		var b = (NumberFormat.ParseInt(parts[1].Substring(dot + 1)) case .Ok(let minor));
		if (dot <= 0 || !a || !b
			|| major < 0 || major > 65535 || minor < 0 || minor > 65535)
		{
			Fail("SER0102", scope $"'{parts[1]}' is not a valid format version (expected <major>.<minor>)", mLineNumbers[mIndex - 1]);
			return false;
		}
		mDocument.mVersion = SchemaVersion((uint16)major, (uint16)minor);
		return true;
	}

	static bool IsName(StringView text)
	{
		if (text.IsEmpty)
			return false;
		for (let c in text)
		{
			let bOk = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '.';
			if (!bOk)
				return false;
		}
		return true;
	}

	DocumentNode ParseNode(int depth)
	{
		if (depth > cMaxDepth)
		{
			Fail("SER0111", scope $"nesting is deeper than {cMaxDepth} levels");
			return null;
		}
		if (!Next(var header))
		{
			Fail("SER0103", "expected a node header (<Type> <id>) but the file ended");
			return null;
		}
		let headerLine = mLineNumbers[mIndex - 1];

		let parts = scope List<StringView>();
		for (let part in header.Split(' ', .RemoveEmptyEntries))
			parts.Add(part);
		if (parts.Count != 2 || !IsName(parts[0]))
		{
			Fail("SER0103", scope $"expected a node header '<Type> <id>' but found '{header}'", headerLine);
			return null;
		}

		let node = new DocumentNode();
		node.mType.Set(parts[0]);
		if (parts[1] != "-")
		{
			if (StableId.Parse(parts[1]) case .Ok(let id))
				node.mId = id;
			else
			{
				Fail("SER0104", scope $"'{parts[1]}' is not a valid id (16 hex digits or '-')", headerLine);
				delete node;
				return null;
			}
		}

		if (!Next(var open) || open != "{")
		{
			Fail("SER0105", scope $"expected '{{' after the header of '{node.mType}'", mLineNumbers[Math.Max(mIndex - 1, 0)]);
			delete node;
			return null;
		}

		while (true)
		{
			if (!Next(var line))
			{
				Fail("SER0106", scope $"the file ended inside '{node.mType}' (missing '}}')");
				delete node;
				return null;
			}
			let lineNumber = mLineNumbers[mIndex - 1];

			if (line == "}")
				return node;

			if (line.EndsWith('['))
			{
				let name = StringView(line);
				name.Substring(0, line.Length - 1).Trim();
				if (!IsName(name))
				{
					Fail("SER0107", scope $"'{name}' is not a valid group name", lineNumber);
					delete node;
					return null;
				}
				let group = new DocumentGroup();
				group.mName.Set(name);
				node.mGroups.Add(group);

				while (true)
				{
					if (mIndex >= mLines.Count)
					{
						Fail("SER0106", scope $"the file ended inside the group '{name}' (missing ']')");
						delete node;
						return null;
					}
					if (mLines[mIndex] == "]")
					{
						mIndex++;
						break;
					}
					let child = ParseNode(depth + 1);
					if (child == null)
					{
						delete node;
						return null;
					}
					group.mNodes.Add(child);
				}
				continue;
			}

			if (!ParseField(node, line, lineNumber))
			{
				delete node;
				return null;
			}
		}
	}

	bool ParseField(DocumentNode node, StringView line, int lineNumber)
	{
		let colon = line.IndexOf(':');
		let equals = line.IndexOf('=');
		if (colon <= 0 || equals < colon)
		{
			Fail("SER0108", scope $"expected a field 'name:kind = value' but found '{line}'", lineNumber);
			return false;
		}

		let name = StringView(line);
		name.Substring(0, colon).Trim();

		let kindName = StringView(line);
		kindName.Substring(colon + 1, equals - colon - 1).Trim();
		let payload = StringView(line);
		payload.Substring(equals + 1).Trim();

		if (!IsName(name))
		{
			Fail("SER0108", scope $"'{name}' is not a valid field name", lineNumber);
			return false;
		}
		if (node.FindField(name) != null)
		{
			Fail("SER0112", scope $"the field '{name}' appears twice in '{node.mType}'", lineNumber);
			return false;
		}
		if (!(ValueCodec.ParseKind(kindName) case .Ok(let kind)))
		{
			Fail("SER0109", scope $"unknown value kind '{kindName}' (expected none, bool, int, float, string, enum, id, vector2, color or rect)", lineNumber);
			return false;
		}

		let error = scope String();
		if (!(ValueCodec.Read(kind, payload, mDocument.mStrings, error) case .Ok(let value)))
		{
			Fail("SER0109", scope $"field '{name}': {error}", lineNumber);
			return false;
		}

		let field = new DocumentField();
		field.mName.Set(name);
		field.mValue = value;
		node.mFields.Add(field);
		return true;
	}
}
