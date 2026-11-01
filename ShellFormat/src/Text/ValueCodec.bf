namespace Shell.Format;

using System;
using System.Collections;
using Shell.Core;
using Shell.Serialization;

// Text form of Value payloads. A field line is  `name:kind = payload`:
//   none = none            bool = true | false          int = -?digits            float = number (see NumberFormat)
//   string = "..."         enum = Identifier            id = 16 hex digits | -    vector2 = x y
//   color = r g b a (floats, 0..1)                       rect = x y width height
static class ValueCodec
{
	static public StringView KindName(ValueKind kind)
	{
		switch (kind)
		{
		case .None: return "none";
		case .Bool: return "bool";
		case .Int: return "int";
		case .Float: return "float";
		case .String: return "string";
		case .Vector2: return "vector2";
		case .Color: return "color";
		case .Rect: return "rect";
		case .Id: return "id";
		case .Enum: return "enum";
		case .Handle: return "handle";      // runtime only; the writer refuses to emit it
		}
	}

	static public Result<ValueKind> ParseKind(StringView name)
	{
		switch (name)
		{
		case "none": return .Ok(.None);
		case "bool": return .Ok(.Bool);
		case "int": return .Ok(.Int);
		case "float": return .Ok(.Float);
		case "string": return .Ok(.String);
		case "vector2": return .Ok(.Vector2);
		case "color": return .Ok(.Color);
		case "rect": return .Ok(.Rect);
		case "id": return .Ok(.Id);
		case "enum": return .Ok(.Enum);
		default: return .Err;
		}
	}

	// Returns false for kinds that must not be saved (runtime handles).
	static public bool Write(Value value, String output)
	{
		switch (value.mKind)
		{
		case .None: output.Append("none");
		case .Bool: output.Append((value.mInt != 0) ? "true" : "false");
		case .Int: NumberFormat.WriteInt(value.mInt, output);
		case .Float: NumberFormat.WriteDouble(value.mFloat, output);
		case .String: StringEscape.Write(value.mString, output);
		case .Enum: output.Append(value.mString);
		case .Id:
			if (value.mInt == 0) output.Append('-');
			else value.AsId().ToString(output);
		case .Vector2:
			NumberFormat.WriteFloat(value.mX, output); output.Append(' ');
			NumberFormat.WriteFloat(value.mY, output);
		case .Color, .Rect:
			NumberFormat.WriteFloat(value.mX, output); output.Append(' ');
			NumberFormat.WriteFloat(value.mY, output); output.Append(' ');
			NumberFormat.WriteFloat(value.mZ, output); output.Append(' ');
			NumberFormat.WriteFloat(value.mW, output);
		case .Handle:
			return false;
		}
		return true;
	}

	static bool ReadFloats(StringView text, int count, float[4] output, String error)
	{
		var index = 0;
		for (let token in text.Split(' ', .RemoveEmptyEntries))
		{
			if (index >= count)
			{
				error.Set(scope $"expected {count} numbers");
				return false;
			}
			if (NumberFormat.ParseFloat(token) case .Ok(let number))
				output[index] = number;
			else
			{
				error.Set(scope $"'{token}' is not a valid number");
				return false;
			}
			index++;
		}
		if (index != count)
		{
			error.Set(scope $"expected {count} numbers");
			return false;
		}
		return true;
	}

	static bool IsIdentifier(StringView text)
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

	// Strings are interned into `pool` (the document or project pool).
	static public Result<Value> Read(ValueKind kind, StringView text, StringPool pool, String error)
	{
		switch (kind)
		{
		case .None:
			if (text != "none") { error.Set("expected 'none'"); return .Err; }
			return .Ok(Value.sNone);
		case .Bool:
			if (text == "true") return .Ok(Value.FromBool(true));
			if (text == "false") return .Ok(Value.FromBool(false));
			error.Set("expected 'true' or 'false'");
			return .Err;
		case .Int:
			if (NumberFormat.ParseInt(text) case .Ok(let number))
				return .Ok(Value.FromInt(number));
			error.Set(scope $"'{text}' is not a valid integer");
			return .Err;
		case .Float:
			if (NumberFormat.ParseDouble(text) case .Ok(let number))
				return .Ok(Value.FromFloat(number));
			error.Set(scope $"'{text}' is not a valid number");
			return .Err;
		case .String:
		{
			let decoded = scope String();
			if (!StringEscape.Read(text, decoded, error))
				return .Err;
			return .Ok(Value.FromString(pool.Intern(decoded)));
		}
		case .Enum:
			if (!IsIdentifier(text)) { error.Set(scope $"'{text}' is not a valid identifier"); return .Err; }
			return .Ok(Value.FromEnum(pool.Intern(text)));
		case .Id:
			if (text == "-") return .Ok(Value.FromId(StableId.sNone));
			if (StableId.Parse(text) case .Ok(let id))
				return .Ok(Value.FromId(id));
			error.Set(scope $"'{text}' is not a valid id (16 hex digits)");
			return .Err;
		case .Vector2:
		{
			float[4] numbers = default;
			if (!ReadFloats(text, 2, numbers, error)) return .Err;
			return .Ok(Value.FromVector2(numbers[0], numbers[1]));
		}
		case .Color:
		{
			float[4] numbers = default;
			if (!ReadFloats(text, 4, numbers, error)) return .Err;
			return .Ok(Value.FromColor(numbers[0], numbers[1], numbers[2], numbers[3]));
		}
		case .Rect:
		{
			float[4] numbers = default;
			if (!ReadFloats(text, 4, numbers, error)) return .Err;
			return .Ok(Value.FromRect(numbers[0], numbers[1], numbers[2], numbers[3]));
		}
		case .Handle:
			error.Set("runtime handles cannot be stored in a file");
			return .Err;
		}
	}
}
