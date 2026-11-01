namespace Shell.Format;

using System;

// Locale-independent number text for the saved format.
//
// Grammar (the only accepted forms):  int   := -? digit+
//                                      float := -? digit+ ( . digit+ )? ( (e|E) (+|-)? digit+ )?  |  nan | inf | -inf
// Writing uses Beef's float/double ToString, which is culture-neutral (always '.'), and verifies that the text parses back
// to the identical value; parsing validates the grammar first, so "1,5" or "1 000" are rejected instead of being
// interpreted according to the machine's regional settings.
static class NumberFormat
{
	static public bool IsValidInteger(StringView text)
	{
		var i = 0;
		if (i < text.Length && text[i] == '-')
			i++;
		let start = i;
		while (i < text.Length && text[i] >= '0' && text[i] <= '9')
			i++;
		return i > start && i == text.Length;
	}

	static public bool IsValidFloat(StringView text)
	{
		if (text == "nan" || text == "inf" || text == "-inf")
			return true;

		var i = 0;
		if (i < text.Length && text[i] == '-')
			i++;
		var digits = 0;
		while (i < text.Length && text[i] >= '0' && text[i] <= '9') { i++; digits++; }
		if (digits == 0)
			return false;

		if (i < text.Length && text[i] == '.')
		{
			i++;
			var fraction = 0;
			while (i < text.Length && text[i] >= '0' && text[i] <= '9') { i++; fraction++; }
			if (fraction == 0)
				return false;
		}
		if (i < text.Length && (text[i] == 'e' || text[i] == 'E'))
		{
			i++;
			if (i < text.Length && (text[i] == '+' || text[i] == '-'))
				i++;
			var exponent = 0;
			while (i < text.Length && text[i] >= '0' && text[i] <= '9') { i++; exponent++; }
			if (exponent == 0)
				return false;
		}
		return i == text.Length;
	}

	static public Result<int64> ParseInt(StringView text)
	{
		if (!IsValidInteger(text))
			return .Err;
		return int64.Parse(text);
	}

	static public Result<double> ParseDouble(StringView text)
	{
		if (!IsValidFloat(text))
			return .Err;
		if (text == "nan") return .Ok(double.NaN);
		if (text == "inf") return .Ok(double.PositiveInfinity);
		if (text == "-inf") return .Ok(double.NegativeInfinity);
		return double.Parse(text);
	}

	static public Result<float> ParseFloat(StringView text)
	{
		if (!IsValidFloat(text))
			return .Err;
		if (text == "nan") return .Ok(float.NaN);
		if (text == "inf") return .Ok(float.PositiveInfinity);
		if (text == "-inf") return .Ok(float.NegativeInfinity);
		return float.Parse(text);
	}

	static public void WriteInt(int64 value, String output)
	{
		value.ToString(output);
	}

	static public void WriteDouble(double value, String output)
	{
		if (value != value) { output.Append("nan"); return; }
		if (value == double.PositiveInfinity) { output.Append("inf"); return; }
		if (value == double.NegativeInfinity) { output.Append("-inf"); return; }
		value.ToString(output);
	}

	static public void WriteFloat(float value, String output)
	{
		if (value != value) { output.Append("nan"); return; }
		if (value == float.PositiveInfinity) { output.Append("inf"); return; }
		if (value == float.NegativeInfinity) { output.Append("-inf"); return; }
		value.ToString(output);
	}
}
