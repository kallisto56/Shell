namespace Shell.Format;

using System;

// String literals of the saved format: double quoted, UTF-8, with the escapes \" \\ \n \r \t and \uXXXX (control
// characters are always escaped so that every value stays on one line). The reader also accepts surrogate pairs
// written as two \u escapes.
static class StringEscape
{
	static public void Write(StringView text, String output)
	{
		output.Append('"');
		for (let c in text.DecodedChars)
		{
			switch (c)
			{
			case '"': output.Append("\\\"");
			case '\\': output.Append("\\\\");
			case '\n': output.Append("\\n");
			case '\r': output.Append("\\r");
			case '\t': output.Append("\\t");
			default:
				if ((uint32)c < 0x20 || (uint32)c == 0x7F)
				{
					let digits = "0123456789abcdef";
					output.Append("\\u00");
					output.Append(digits[(int)(((uint32)c >> 4) & 0xF)]);
					output.Append(digits[(int)((uint32)c & 0xF)]);
				}
				else
				{
					output.Append(c);
				}
			}
		}
		output.Append('"');
	}

	// text includes the surrounding quotes. On failure `error` describes the problem.
	static public bool Read(StringView text, String output, String error)
	{
		if (text.Length < 2 || text[0] != '"' || text[text.Length - 1] != '"')
		{
			error.Set("a string must be enclosed in double quotes");
			return false;
		}

		let body = text.Substring(1, text.Length - 2);
		var i = 0;
		uint32 pendingHigh = 0;
		while (i < body.Length)
		{
			let c = body[i];
			if (c == '"')
			{
				error.Set("unescaped double quote inside a string");
				return false;
			}
			if (c != '\\')
			{
				if (pendingHigh != 0)
				{
					error.Set("a high surrogate escape must be followed by a low surrogate escape");
					return false;
				}
				output.Append(c);
				i++;
				continue;
			}

			i++;
			if (i >= body.Length)
			{
				error.Set("a string ends with a lone backslash");
				return false;
			}

			let e = body[i];
			i++;
			if (e == 'u')
			{
				if (i + 4 > body.Length)
				{
					error.Set("\\u needs four hex digits");
					return false;
				}
				uint32 code = 0;
				for (int k < 4)
				{
					let h = body[i + k];
					uint32 digit;
					if (h >= '0' && h <= '9') digit = (uint32)(h - '0');
					else if (h >= 'a' && h <= 'f') digit = (uint32)(h - 'a') + 10;
					else if (h >= 'A' && h <= 'F') digit = (uint32)(h - 'A') + 10;
					else
					{
						error.Set("\\u needs four hex digits");
						return false;
					}
					code = (code << 4) | digit;
				}
				i += 4;

				if (code >= 0xD800 && code <= 0xDBFF)
				{
					if (pendingHigh != 0) { error.Set("two high surrogates in a row"); return false; }
					pendingHigh = code;
					continue;
				}
				if (code >= 0xDC00 && code <= 0xDFFF)
				{
					if (pendingHigh == 0) { error.Set("a low surrogate without a high surrogate"); return false; }
					let combined = 0x10000 + ((pendingHigh - 0xD800) << 10) + (code - 0xDC00);
					pendingHigh = 0;
					output.Append((char32)combined);
					continue;
				}
				if (pendingHigh != 0) { error.Set("a high surrogate escape must be followed by a low surrogate escape"); return false; }
				output.Append((char32)code);
				continue;
			}

			if (pendingHigh != 0)
			{
				error.Set("a high surrogate escape must be followed by a low surrogate escape");
				return false;
			}
			switch (e)
			{
			case '"': output.Append('"');
			case '\\': output.Append('\\');
			case 'n': output.Append('\n');
			case 'r': output.Append('\r');
			case 't': output.Append('\t');
			default:
				error.Set(scope $"unknown escape '\\{e}'");
				return false;
			}
		}

		if (pendingHigh != 0)
		{
			error.Set("a high surrogate escape at the end of a string");
			return false;
		}
		return true;
	}
}
