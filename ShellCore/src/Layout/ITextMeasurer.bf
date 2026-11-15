namespace Shell.Layout;

using System;
using Shell.Core;
using Shell.Elements;

// Measures text elements for layout. Implemented by the renderer (it owns the fonts and the HarfBuzz layout); the layout engine
// only asks for a size. maxWidth <= 0 means "do not wrap".
interface ITextMeasurer
{
	PointF MeasureText(Element element, float maxWidth);
}
