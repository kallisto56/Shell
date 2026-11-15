namespace Shell.Render;

using System;
using Juno;
using Shell.Core;
using Shell.Elements;
using Shell.Layout;

// Text size for layout, measured with the same fonts and shaping the renderer draws with.
class JunoTextMeasurer : ITextMeasurer
{
	FontCatalog mFonts;

	public this(FontCatalog fonts)
	{
		mFonts = fonts;
	}

	public PointF MeasureText(Element element, float maxWidth)
	{
		let p = element.mProperties;
		let text = p.Get(ElementTypes.sTextContent).AsString();
		if (text.IsEmpty)
			return default;
		let font = mFonts.Get(p.Get(ElementTypes.sFontFamily).AsString(), (float)p.Get(ElementTypes.sFontSize).AsFloat(14));
		if (font == null)
			return default;
		let size = font.Measure(text, maxWidth);
		return PointF(size.mX, size.mY);
	}
}
