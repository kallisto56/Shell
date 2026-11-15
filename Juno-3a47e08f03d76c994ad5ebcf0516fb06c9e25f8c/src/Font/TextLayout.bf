namespace Juno;

using System;
using System.Collections;

struct PlacedGlyph
{
	public uint32 mGlyph;       // glyph index in the font (not a code point)
	public float mX;            // pen position of the line start + shaping offset, relative to the text block
	public float mY;            // baseline of the line - vertical shaping offset, relative to the text block top
	public uint32 mCluster;     // byte offset of the source text this glyph belongs to
}

struct LineInfo
{
	public int32 mFirstGlyph;
	public int32 mGlyphCount;
	public float mWidth;
	public float mBaseline;     // distance from the top of the block to the baseline
}

// Result of Font.Layout(): shaped + positioned glyphs, grouped in lines. Reusable (Clear()).
class TextLayout
{
	public List<PlacedGlyph> mGlyphs = new .() ~ delete _;
	public List<LineInfo> mLines = new .() ~ delete _;
	public float mWidth;
	public float mHeight;

	public void Clear()
	{
		this.mGlyphs.Clear();
		this.mLines.Clear();
		this.mWidth = 0;
		this.mHeight = 0;
	}
}
