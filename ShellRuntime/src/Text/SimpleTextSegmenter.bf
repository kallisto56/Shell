namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Text;

// Pragmatic grapheme / word boundaries. Clusters: CR LF, a base followed by combining marks, variation selectors, ZWJ
// sequences, emoji skin tones and tag characters, regional-indicator pairs (flags), Hangul jamo sequences, and the common
// Indic / Thai / Arabic / Hebrew marks. It is a subset of UAX #29 behind ITextSegmenter, so a complete implementation can
// replace it later without touching any widget.
class SimpleTextSegmenter : ITextSegmenter
{
	static bool InRange(uint32 cp, uint32 low, uint32 high) => cp >= low && cp <= high;

	static bool IsExtend(uint32 cp)
	{
		if (cp < 0x300) return false;
		return InRange(cp, 0x300, 0x36F) || InRange(cp, 0x483, 0x489) || InRange(cp, 0x591, 0x5BD) || cp == 0x5BF || InRange(cp, 0x5C1, 0x5C2)
			|| InRange(cp, 0x5C4, 0x5C5) || cp == 0x5C7 || InRange(cp, 0x610, 0x61A) || InRange(cp, 0x64B, 0x65F) || cp == 0x670
			|| InRange(cp, 0x6D6, 0x6DC) || InRange(cp, 0x6DF, 0x6E4) || InRange(cp, 0x6E7, 0x6E8) || InRange(cp, 0x6EA, 0x6ED)
			|| InRange(cp, 0x900, 0x903) || InRange(cp, 0x93A, 0x94F) || InRange(cp, 0x951, 0x957) || InRange(cp, 0x962, 0x963)
			|| InRange(cp, 0x981, 0x983) || InRange(cp, 0x9BC, 0x9CD) || InRange(cp, 0xA01, 0xA03) || InRange(cp, 0xA3C, 0xA51)
			|| InRange(cp, 0xB01, 0xB03) || InRange(cp, 0xB3C, 0xB57) || InRange(cp, 0xB82, 0xB83) || InRange(cp, 0xBBE, 0xBCD)
			|| InRange(cp, 0xC00, 0xC04) || InRange(cp, 0xC3E, 0xC56) || InRange(cp, 0xD00, 0xD03) || InRange(cp, 0xD3B, 0xD4D)
			|| cp == 0xE31 || InRange(cp, 0xE34, 0xE3A) || InRange(cp, 0xE47, 0xE4E) || cp == 0xEB1 || InRange(cp, 0xEB4, 0xEBC)
			|| InRange(cp, 0xEC8, 0xECD) || InRange(cp, 0x1160, 0x11FF) || InRange(cp, 0x1AB0, 0x1AFF) || InRange(cp, 0x1DC0, 0x1DFF)
			|| cp == 0x200C || InRange(cp, 0x20D0, 0x20FF) || InRange(cp, 0x302A, 0x302F) || InRange(cp, 0x3099, 0x309A)
			|| InRange(cp, 0xFE00, 0xFE0F) || InRange(cp, 0xFE20, 0xFE2F) || InRange(cp, 0x1F3FB, 0x1F3FF) || InRange(cp, 0xE0020, 0xE007F)
			|| InRange(cp, 0xE0100, 0xE01EF) || InRange(cp, 0xD7B0, 0xD7FF);
	}

	static bool IsRegionalIndicator(uint32 cp) => InRange(cp, 0x1F1E6, 0x1F1FF);
	static bool IsHangulLead(uint32 cp) => InRange(cp, 0x1100, 0x115F);
	static bool IsPictographic(uint32 cp) => InRange(cp, 0x1F300, 0x1FAFF) || InRange(cp, 0x2600, 0x27BF) || InRange(cp, 0x2190, 0x21FF) || cp == 0x2764;

	public int NextCluster(StringView text, int index)
	{
		if (index >= text.Length)
			return text.Length;

		var cp = Utf8.Decode(text, index, var length);
		var i = index + length;
		if (cp == 0x0D)
		{
			if (i < text.Length && text[i] == '\n')
				i++;
			return i;
		}
		if (cp == 0x0A)
			return i;

		if (IsRegionalIndicator(cp) && i < text.Length)
		{
			let next = Utf8.Decode(text, i, var nextLength);
			if (IsRegionalIndicator(next))
				i += nextLength;
		}

		var previous = cp;
		while (i < text.Length)
		{
			let next = Utf8.Decode(text, i, var nextLength);
			if (IsExtend(next) || next == 0x200D)
			{
				previous = next;
				i += nextLength;
			}
			else if (previous == 0x200D && IsPictographic(next))
			{
				previous = next;
				i += nextLength;
			}
			else if (IsHangulLead(cp) && IsHangulLead(next))
			{
				i += nextLength;
			}
			else
			{
				break;
			}
		}
		return i;
	}

	public int PreviousCluster(StringView text, int index)
	{
		if (index <= 0)
			return 0;

		// Clusters never span a line feed: scan forward from the start of the line containing the position.
		var lineStart = index;
		while (lineStart > 0 && text[lineStart - 1] != '\n')
			lineStart--;

		var boundary = lineStart;
		while (true)
		{
			let next = NextCluster(text, boundary);
			if (next >= index || next <= boundary)
				break;
			boundary = next;
		}
		return (boundary < index) ? boundary : Utf8.PreviousStart(text, index);
	}

	// 0 whitespace, 1 word (letters, digits, underscore, most non-ASCII letters), 2 punctuation / symbols
	static int ClassOf(uint32 cp)
	{
		if (cp == ' ' || cp == '\t' || cp == '\n' || cp == '\r' || cp == 0xA0 || InRange(cp, 0x2000, 0x200A) || cp == 0x2028 || cp == 0x2029 || cp == 0x3000)
			return 0;
		if (cp < 0x80)
		{
			let bAlnum = (cp >= 'a' && cp <= 'z') || (cp >= 'A' && cp <= 'Z') || (cp >= '0' && cp <= '9') || cp == '_';
			return bAlnum ? 1 : 2;
		}
		if (InRange(cp, 0x2010, 0x206F) || InRange(cp, 0x3001, 0x303F) || InRange(cp, 0xFF01, 0xFF0F) || InRange(cp, 0xA1, 0xBF) || IsPictographic(cp))
			return 2;
		return 1;
	}

	public int NextWord(StringView text, int index)
	{
		var i = index;
		if (i >= text.Length)
			return text.Length;

		let first = ClassOf(Utf8.Decode(text, i, var length));
		if (first != 0)
		{
			while (i < text.Length)
			{
				let cp = Utf8.Decode(text, i, var l);
				if (ClassOf(cp) != first)
					break;
				i += l;
			}
		}
		while (i < text.Length)
		{
			let cp = Utf8.Decode(text, i, var l);
			if (ClassOf(cp) != 0)
				break;
			i += l;
		}
		return i;
	}

	public int PreviousWord(StringView text, int index)
	{
		var i = index;
		while (i > 0)
		{
			let start = Utf8.PreviousStart(text, i);
			if (ClassOf(Utf8.Decode(text, start, var l)) != 0)
				break;
			i = start;
		}
		if (i == 0)
			return 0;

		let cls = ClassOf(Utf8.Decode(text, Utf8.PreviousStart(text, i), var l0));
		while (i > 0)
		{
			let start = Utf8.PreviousStart(text, i);
			if (ClassOf(Utf8.Decode(text, start, var l)) != cls)
				break;
			i = start;
		}
		return i;
	}

	public int WordStart(StringView text, int index)
	{
		if (text.IsEmpty)
			return 0;
		var i = Math.Min(index, text.Length);
		if (i >= text.Length)
			i = Utf8.PreviousStart(text, text.Length);
		let cls = ClassOf(Utf8.Decode(text, i, var l0));
		while (i > 0)
		{
			let start = Utf8.PreviousStart(text, i);
			if (ClassOf(Utf8.Decode(text, start, var l)) != cls)
				break;
			i = start;
		}
		return i;
	}

	public int WordEnd(StringView text, int index)
	{
		if (text.IsEmpty)
			return 0;
		var i = Math.Min(index, text.Length);
		if (i >= text.Length)
			return text.Length;
		let cls = ClassOf(Utf8.Decode(text, i, var l0));
		while (i < text.Length)
		{
			let cp = Utf8.Decode(text, i, var l);
			if (ClassOf(cp) != cls)
				break;
			i += l;
		}
		return i;
	}
}
