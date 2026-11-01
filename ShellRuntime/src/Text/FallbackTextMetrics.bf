namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Text;
using Shell.Widgets;

// Stand-in for the real shaped-text metrics: every code point has the same advance and every line the same height. Lets
// TextBox work (caret, selection, mouse placement) before a Text element supplies HarfBuzz based metrics, and in headless tests.
// Bidirectional text is treated as left-to-right here.
class FallbackTextMetrics : ITextMetrics
{
	TextBox mOwner;
	ITextSegmenter mSegmenter;
	public float mAdvance = 8;
	public float mLineHeight = 16;

	public this(TextBox owner, ITextSegmenter segmenter)
	{
		mOwner = owner;
		mSegmenter = segmenter;
	}

	StringView Text => mOwner.mTextView;

	int LineNumber(int index)
	{
		int line = 0;
		let text = Text;
		for (int i < Math.Min(index, text.Length))
		{
			if (text[i] == '\n')
				line++;
		}
		return line;
	}

	public int GetLineStart(int index)
	{
		let text = Text;
		var i = Math.Min(index, text.Length);
		while (i > 0 && text[i - 1] != '\n')
			i--;
		return i;
	}

	public int GetLineEnd(int index)
	{
		let text = Text;
		var i = Math.Min(index, text.Length);
		while (i < text.Length && text[i] != '\n')
			i++;
		return i;
	}

	int ColumnOf(int index)
	{
		let text = Text;
		int column = 0;
		var i = GetLineStart(index);
		while (i < index && i < text.Length)
		{
			i = mSegmenter.NextCluster(text, i);
			column++;
		}
		return column;
	}

	int IndexAt(int lineNumber, int column)
	{
		let text = Text;
		var i = 0;
		for (int line < lineNumber)
		{
			while (i < text.Length && text[i] != '\n')
				i++;
			if (i < text.Length)
				i++;
		}
		for (int c < column)
		{
			if (i >= text.Length || text[i] == '\n')
				break;
			i = mSegmenter.NextCluster(text, i);
		}
		return i;
	}

	int LineCount()
	{
		int count = 1;
		for (let c in Text)
		{
			if (c == '\n')
				count++;
		}
		return count;
	}

	public int HitTest(float x, float y)
	{
		let line = Math.Clamp((int)Math.Floor(y / mLineHeight), 0, LineCount() - 1);
		let column = Math.Max((int)Math.Round(x / mAdvance), 0);
		return IndexAt(line, column);
	}

	public RectF GetCaretRect(int index)
	{
		return RectF((float)ColumnOf(index) * mAdvance, (float)LineNumber(index) * mLineHeight, 1, mLineHeight);
	}

	public void GetSelectionRects(int start, int end, List<RectF> output)
	{
		let text = Text;
		var i = Math.Min(start, end);
		let last = Math.Max(start, end);
		while (i < last)
		{
			let lineEnd = Math.Min(GetLineEnd(i), last);
			let from = GetCaretRect(i);
			let to = GetCaretRect(lineEnd);
			output.Add(RectF(from.mX, from.mY, Math.Max(to.mX - from.mX, 2), mLineHeight));
			i = lineEnd;
			if (i < text.Length && text[i] == '\n')
				i++;
		}
	}

	public int MoveVisual(int index, int direction)
	{
		return (direction < 0) ? mSegmenter.PreviousCluster(Text, index) : mSegmenter.NextCluster(Text, index);
	}

	public int MoveLine(int index, int direction, float desiredX)
	{
		let line = LineNumber(index) + direction;
		if (line < 0 || line >= LineCount())
			return index;
		return IndexAt(line, (int)Math.Round(desiredX / mAdvance));
	}
}
