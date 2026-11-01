namespace Shell.Platform;

using System;
using Shell.Core;

// Implemented by a text-editing widget. Offsets are UTF-16 code units (what IMEs and TSF use); the widget converts to its
// own representation. Text is never assumed to be left-to-right or one character per glyph.
interface ITextInputClient
{
	void GetSelection(out int start, out int end);
	void SetSelection(int start, int end);
	// Replaces the range with text (committed input).
	void ReplaceText(int start, int end, StringView text);
	// Pre-edit (composition) text shown while an IME is converting; null/empty clears it.
	void SetComposition(StringView text, int cursor);
	void CommitComposition();
	// Screen-space rectangle of the caret / composition, used to position the IME candidate window.
	RectF GetCaretRect();
	int GetTextLength();
}
