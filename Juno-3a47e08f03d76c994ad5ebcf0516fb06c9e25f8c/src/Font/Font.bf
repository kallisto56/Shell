namespace Juno;

using System;
using System.Collections;
using System.IO;
using System.Interop;
using FreeType;
using HarfBuzz;

// A TrueType/OpenType font at one pixel size. Text is shaped with HarfBuzz (kerning, ligatures, Arabic/Indic
// joining ...) and rasterized with FreeType into atlas pages on demand. One Font object = one size; load the
// same file twice for two sizes.
//
// Layout notes: line breaking is greedy at spaces and works in visual order, so it is meant for left-to-right
// paragraphs. Right-to-left runs are shaped correctly by HarfBuzz but there is no bidi reordering of mixed text.
class Font
{
	public struct GlyphEntry
	{
		public int32 mPage;
		public float mU0, mV0, mU1, mV1;
		public float mWidth, mHeight;           // bitmap size in pixels
		public float mBearingX, mBearingY;      // bitmap left / top relative to the pen position on the baseline
		public bool bHasBitmap;                 // false for spaces and other empty glyphs
	}

	public const int32 cPageSize = 1024;

	static FT_Library sLibrary;
	static int sLibraryUsers;

	public Device* mDevice;
	public int32 mPixelSize;
	public float mAscent;           // pixels above the baseline
	public float mDescent;          // pixels below the baseline (positive)
	public float mLineHeight;       // distance between two baselines
	public List<FontPage> mPages = new .() ~ DeleteContainerAndItems!(_);

	List<uint8> mFileData = new .() ~ delete _;     // must outlive the FT face
	FT_Face mFace;
	hb_font_t* mHbFont;
	hb_buffer_t* mHbBuffer;
	Dictionary<uint32, GlyphEntry> mGlyphs = new .() ~ delete _;

	public ~this()
	{
		if (mHbBuffer != null) hb_buffer_destroy(mHbBuffer);
		if (mHbFont != null) hb_font_destroy(mHbFont);
		if (mFace != null) FT_Done_Face(mFace);

		if (sLibraryUsers > 0)
		{
			sLibraryUsers--;
			if (sLibraryUsers == 0)
			{
				FT_Done_FreeType(sLibrary);
				sLibrary = null;
			}
		}
	}

	static public Result<Font> Load(Device* device, StringView path, int pixelSize)
	{
		let font = new Font();
		if (File.ReadAll(path, font.mFileData) case .Err)
		{
			Console.WriteLine("[Juno] Could not read font file '{}'", path);
			delete font;
			return .Err;
		}
		if (!font.Initialize(device, pixelSize))
		{
			delete font;
			return .Err;
		}
		return .Ok(font);
	}

	static public Result<Font> LoadFromMemory(Device* device, Span<uint8> data, int pixelSize)
	{
		let font = new Font();
		font.mFileData.AddRange(data);
		if (!font.Initialize(device, pixelSize))
		{
			delete font;
			return .Err;
		}
		return .Ok(font);
	}

	bool Initialize(Device* device, int pixelSize)
	{
		mDevice = device;
		mPixelSize = (int32)pixelSize;

		if (sLibraryUsers == 0)
		{
			if (FT_Init_FreeType(var library) != .FT_Err_Ok)
				return false;
			sLibrary = library;
		}
		sLibraryUsers++;

		if (FT_New_Memory_Face(sLibrary, mFileData.Ptr, (FT_Long)mFileData.Count, 0, var face) != .FT_Err_Ok)
			return false;
		mFace = face;

		if (FT_Set_Pixel_Sizes(mFace, 0, (FT_UInt)pixelSize) != .FT_Err_Ok)
			return false;

		let metrics = mFace.size.metrics;
		mAscent = (float)metrics.ascender / (float)FT_FIXED_POINT_SCALE;
		mDescent = -(float)metrics.descender / (float)FT_FIXED_POINT_SCALE;
		mLineHeight = (float)metrics.height / (float)FT_FIXED_POINT_SCALE;

		mHbFont = hb_ft_font_create_referenced(mFace);
		mHbBuffer = hb_buffer_create();
		return mHbFont != null && mHbBuffer != null;
	}

	// ---------------------------------------------------------------------------------------------------------
	// Glyphs
	// ---------------------------------------------------------------------------------------------------------

	FontPage CreatePage()
	{
		let zeros = new uint8[cPageSize * cPageSize * 4];
		defer delete zeros;

		if (Texture2D.Create(mDevice, cPageSize, cPageSize, .R8G8B8A8_UNorm, &zeros[0], cPageSize * 4, false) case .Ok(let texture))
		{
			let page = new FontPage(cPageSize);
			page.mTexture = texture;
			mPages.Add(page);
			return page;
		}
		return null;
	}

	// Returns the atlas entry of a glyph index (as produced by shaping), rasterizing it on first use.
	public GlyphEntry GetGlyph(uint32 glyphIndex)
	{
		if (mGlyphs.TryGetValue(glyphIndex, let cached))
			return cached;

		GlyphEntry entry = default;
		if (FT_Load_Glyph(mFace, (FT_UInt)glyphIndex, .FT_LOAD_RENDER) == .FT_Err_Ok)
		{
			let slot = mFace.glyph;
			let bitmap = slot.bitmap;
			let w = (int)bitmap.width;
			let h = (int)bitmap.rows;
			let bGray = ((int)bitmap.pixel_mode == 2);      // FT_PIXEL_MODE_GRAY

			if (w > 0 && h > 0 && bGray)
				Bake(ref entry, slot, w, h);
		}

		mGlyphs[glyphIndex] = entry;
		return entry;
	}

	void Bake(ref GlyphEntry entry, FT_GlyphSlot slot, int w, int h)
	{
		int px = 0;
		int py = 0;
		bool bPacked = false;
		FontPage page = null;
		if (mPages.Count > 0)
		{
			page = mPages.Back;
			bPacked = page.TryPack(w, h, out px, out py);
		}
		if (!bPacked)
		{
			page = CreatePage();
			if (page == null)
				return;
			bPacked = page.TryPack(w, h, out px, out py);
			if (!bPacked)
				return;     // glyph larger than a page: skipped
		}

		// Expand 8-bit coverage to white RGBA so the regular shaders can tint it.
		let bitmap = slot.bitmap;
		let pitch = (int)bitmap.pitch;
		let rgba = new uint8[w * h * 4];
		defer delete rgba;
		for (int y < h)
		{
			let rowStart = (pitch >= 0) ? (y * pitch) : ((h - 1 - y) * -pitch);
			let src = bitmap.buffer + rowStart;
			for (int x < w)
			{
				let o = (y * w + x) * 4;
				rgba[o] = 255;
				rgba[o + 1] = 255;
				rgba[o + 2] = 255;
				rgba[o + 3] = src[x];
			}
		}

		Region region = Region((c_int)px, (c_int)py, (c_int)(px + w), (c_int)(py + h));
		page.mTexture.Update(&region, &rgba[0], w * 4);

		let size = (float)cPageSize;
		entry.mPage = (int32)(mPages.Count - 1);
		entry.mU0 = (float)px / size;
		entry.mV0 = (float)py / size;
		entry.mU1 = (float)(px + w) / size;
		entry.mV1 = (float)(py + h) / size;
		entry.mWidth = (float)w;
		entry.mHeight = (float)h;
		entry.mBearingX = (float)slot.bitmap_left;
		entry.mBearingY = (float)slot.bitmap_top;
		entry.bHasBitmap = true;
	}

	// ---------------------------------------------------------------------------------------------------------
	// Shaping + layout
	// ---------------------------------------------------------------------------------------------------------

	// Shapes `text` (UTF-8) with HarfBuzz and breaks it into lines. maxWidth <= 0 disables wrapping.
	public void Layout(StringView text, float maxWidth, TextLayout layout)
	{
		layout.Clear();

		int lineIndex = 0;
		int start = 0;
		while (true)
		{
			int end = text.IndexOf('\n', start);
			if (end < 0)
				end = text.Length;

			var paragraph = text.Substring(start, end - start);
			if (paragraph.EndsWith('\r'))
				paragraph.Length--;

			LayoutParagraph(paragraph, maxWidth, layout, ref lineIndex);

			if (end >= text.Length)
				break;
			start = end + 1;
		}
		layout.mHeight = (float)lineIndex * mLineHeight;
	}

	public Vector2 Measure(StringView text, float maxWidth = 0)
	{
		let layout = scope TextLayout();
		Layout(text, maxWidth, layout);
		return Vector2(layout.mWidth, layout.mHeight);
	}

	void LayoutParagraph(StringView paragraph, float maxWidth, TextLayout layout, ref int lineIndex)
	{
		if (paragraph.Length == 0)
		{
			AddLine(layout, null, null, 0, 0, lineIndex);
			lineIndex++;
			return;
		}

		hb_buffer_clear_contents(mHbBuffer);
		hb_buffer_add_utf8(mHbBuffer, paragraph.Ptr, (c_int)paragraph.Length, 0, (c_int)paragraph.Length);
		hb_buffer_guess_segment_properties(mHbBuffer);
		hb_shape(mHbFont, mHbBuffer, null, 0);

		let infos = hb_buffer_get_glyph_infos(mHbBuffer, var count);
		let positions = hb_buffer_get_glyph_positions(mHbBuffer, var countPositions);
		let n = (int)count;

		int lineStart = 0;
		float lineWidth = 0;
		int lastBreak = -1;             // glyph index where a line may start (after a space)
		float widthAtBreak = 0;

		for (int i < n)
		{
			let advance = (float)positions[i].x_advance / (float)FT_FIXED_POINT_SCALE;
			let bSpace = IsSpace(paragraph, infos[i].cluster);

			if (maxWidth > 0 && lineWidth + advance > maxWidth && i > lineStart && !bSpace)
			{
				int breakAt = i;
				float widthAtLine = lineWidth;
				if (lastBreak > lineStart)
				{
					breakAt = lastBreak;
					widthAtLine = widthAtBreak;
				}

				AddLine(layout, infos, positions, lineStart, breakAt, lineIndex);
				lineIndex++;

				lineStart = breakAt;
				lineWidth = 0;
				for (int j = lineStart; j < i; j++)
					lineWidth += (float)positions[j].x_advance / (float)FT_FIXED_POINT_SCALE;
				lastBreak = -1;
			}

			lineWidth += advance;
			if (bSpace)
			{
				lastBreak = i + 1;
				widthAtBreak = lineWidth;
			}
		}

		AddLine(layout, infos, positions, lineStart, n, lineIndex);
		lineIndex++;
	}

	static bool IsSpace(StringView paragraph, uint32 cluster)
	{
		if ((int)cluster >= paragraph.Length)
			return false;
		let c = paragraph[(int)cluster];
		return c == ' ' || c == '\t';
	}

	void AddLine(TextLayout layout, hb_glyph_info_t* infos, hb_glyph_position_t* positions, int start, int end, int lineIndex)
	{
		let baseline = mAscent + (float)lineIndex * mLineHeight;
		let first = layout.mGlyphs.Count;

		float x = 0;
		for (int i = start; i < end; i++)
		{
			PlacedGlyph placed = default;
			placed.mGlyph = infos[i].codepoint;
			placed.mCluster = infos[i].cluster;
			placed.mX = x + (float)positions[i].x_offset / (float)FT_FIXED_POINT_SCALE;
			placed.mY = baseline - (float)positions[i].y_offset / (float)FT_FIXED_POINT_SCALE;
			layout.mGlyphs.Add(placed);
			x += (float)positions[i].x_advance / (float)FT_FIXED_POINT_SCALE;
		}

		LineInfo line = default;
		line.mFirstGlyph = (int32)first;
		line.mGlyphCount = (int32)(end - start);
		line.mWidth = x;
		line.mBaseline = baseline;
		layout.mLines.Add(line);
		layout.mWidth = Math.Max(layout.mWidth, x);
	}
}
