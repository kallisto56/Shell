namespace Shell.Text;

using System;

// Text boundaries used for caret movement, deletion and word selection. Positions are byte offsets into UTF-8 text.
// Caret movement works on grapheme clusters, never on bytes or code points. The runtime ships a pragmatic implementation
// (combining marks, ZWJ sequences, variation selectors, emoji modifiers, regional-indicator pairs, CRLF, common Indic/Thai/Hangul
// marks); a full UAX #29 implementation can replace it without touching the widgets.
interface ITextSegmenter
{
	int NextCluster(StringView text, int index);        // boundary after the cluster that starts at/contains index
	int PreviousCluster(StringView text, int index);    // boundary before index
	int NextWord(StringView text, int index);
	int PreviousWord(StringView text, int index);
	int WordStart(StringView text, int index);          // word containing index (double click)
	int WordEnd(StringView text, int index);
}
