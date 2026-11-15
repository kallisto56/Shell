namespace Shell.Text;

using System;
using System.Collections;
using Shell.Core;

// Geometry of shaped text, provided by whatever draws it (the Text element, backed by HarfBuzz layout). Coordinates are
// local to the TextBox. Offsets are byte offsets into the TextBox's UTF-8 text.
// Needed because a caret position is a property of the *shaped* text: bidirectional runs, ligatures and line wrapping
// cannot be derived from the string alone.
interface ITextMetrics
{
	int HitTest(float x, float y);                                  // nearest caret position to a point
	RectF GetCaretRect(int index);
	void GetSelectionRects(int start, int end, List<RectF> output); // one rectangle per visual run / line
	int MoveVisual(int index, int direction);                       // -1 = visually left, +1 = visually right (bidi aware)
	int MoveLine(int index, int direction, float desiredX);         // -1 = up, +1 = down; returns index (unchanged at the ends)
	int GetLineStart(int index);
	int GetLineEnd(int index);
}
