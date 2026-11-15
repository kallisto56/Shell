namespace Shell.Render;

using System;
using System.Collections;
using Juno;
using Shell.Core;
using Shell.Elements;
using Shell.Rendering;
using Shell.Layout;

// Draws the own content of one element in its local space (origin = top-left of the element box). The caller has already pushed the
// element's transform, clip and opacity.
class ElementPainter
{
	FontCatalog mFonts;
	ImageCatalog mImages;
	ShapePainter mShapes = new .() ~ delete _;
	public double mDeltaSeconds;        // set by the renderer for video elements

	public this(FontCatalog fonts, ImageCatalog images)
	{
		mFonts = fonts;
		mImages = images;
	}

	public void Paint(Graphics g, Element element)
	{
		let rect = element.mArranged;
		switch (element.mKind)
		{
		case .Shape: PaintShape(g, element, rect.mWidth, rect.mHeight);
		case .Path: PaintPath(g, element, rect.mWidth, rect.mHeight);
		case .Text: PaintText(g, element, rect.mWidth, rect.mHeight);
		case .Image, .Video: PaintMedia(g, element, rect.mWidth, rect.mHeight);
		default:
		}
	}

	void PaintShape(Graphics g, Element element, float width, float height)
	{
		let p = element.mProperties;
		var kind = ShapeKind.Rectangle;
		if (Enum.Parse<ShapeKind>(p.Get(ElementTypes.sShapeKind).AsString()) case .Ok(let parsed))
			kind = parsed;
		mShapes.PaintShape(g, kind, width, height, (float)p.Get(ElementTypes.sCornerRadius).AsFloat(),
			(float)p.Get(ElementTypes.sStrokeWidth).AsFloat(1), ColorConvert.To(p.Get(ElementTypes.sFill)), ColorConvert.To(p.Get(ElementTypes.sStroke)));
	}

	void PaintPath(Graphics g, Element element, float width, float height)
	{
		let geometry = element.GetPathGeometry();
		if (geometry == null || geometry.mContours.Count == 0)
			return;

		let p = element.mProperties;
		var stretch = ImageStretch.None;
		if (Enum.Parse<ImageStretch>(p.Get(ElementTypes.sPathStretch).AsString()) case .Ok(let parsed))
			stretch = parsed;

		// Fit the path bounds into the element box.
		let bounds = geometry.mBounds;
		var matrix = Matrix3x2.sIdentity;
		if (stretch != .None && bounds.mWidth > 0 && bounds.mHeight > 0)
		{
			var sx = width / bounds.mWidth;
			var sy = height / bounds.mHeight;
			if (stretch == .Uniform) { sx = Math.Min(sx, sy); sy = sx; }
			else if (stretch == .UniformToFill) { sx = Math.Max(sx, sy); sy = sx; }
			matrix = Matrix3x2.CreateTranslation(Vector2(-bounds.mX, -bounds.mY)) * Matrix3x2.CreateScale(Vector2(sx, sy));
		}

		g.PushTransform(matrix);
		let fill = ColorConvert.To(p.Get(ElementTypes.sFill));
		let stroke = ColorConvert.To(p.Get(ElementTypes.sStroke));
		let strokeWidth = (float)p.Get(ElementTypes.sStrokeWidth).AsFloat(1);
		if (fill.mA > 0)
			mShapes.FillPath(g, geometry, fill);
		if (stroke.mA > 0 && strokeWidth > 0)
		{
			for (let contour in geometry.mContours)
				mShapes.StrokePolyline(g, contour.mPoints, contour.bClosed, strokeWidth, stroke);
		}
		g.PopTransform();
	}

	void PaintText(Graphics g, Element element, float width, float height)
	{
		let p = element.mProperties;
		let text = p.Get(ElementTypes.sTextContent).AsString();
		if (text.IsEmpty)
			return;
		let font = mFonts.Get(p.Get(ElementTypes.sFontFamily).AsString(), (float)p.Get(ElementTypes.sFontSize).AsFloat(14));
		if (font == null)
			return;

		var align = TextHorizontalAlign.Left;
		if (Enum.Parse<TextHorizontalAlign>(p.Get(ElementTypes.sTextAlign).AsString()) case .Ok(let parsed))
			align = parsed;
		let color = ColorConvert.To(p.Get(ElementTypes.sTextColor));

		if (p.Get(ElementTypes.sWrap).AsBool())
		{
			let juno = (align == .Center) ? TextAlign.Center : ((align == .Right) ? TextAlign.Right : TextAlign.Left);
			g.DrawString(font, text, 0, 0, color, juno, width);
			return;
		}

		var x = 0.0f;
		if (align != .Left)
		{
			let size = font.Measure(text);
			x = (align == .Center) ? (width - size.mX) * 0.5f : (width - size.mX);
		}
		g.DrawString(font, text, x, 0, color);
	}

	void PaintMedia(Graphics g, Element element, float width, float height)
	{
		let p = element.mProperties;
		let source = p.Get(ElementTypes.sSource).AsString();
		Texture2D texture = null;
		if (element.mKind == .Video)
			texture = mImages.GetVideoFrame(source, mDeltaSeconds, p.Get(ElementTypes.sPlaying).AsBool(true), p.Get(ElementTypes.sLoop).AsBool(true));
		else
			texture = mImages.Get(source);
		if (texture == null)
			return;

		var stretch = ImageStretch.Uniform;
		if (Enum.Parse<ImageStretch>(p.Get(ElementTypes.sStretch).AsString()) case .Ok(let parsed))
			stretch = parsed;
		let tint = ColorConvert.To(p.Get(ElementTypes.sTint));

		let tw = (float)texture.mWidth;
		let th = (float)texture.mHeight;
		var dest = Rect(0, 0, width, height);
		var src = Rect(0, 0, tw, th);
		switch (stretch)
		{
		case .None:
			dest = Rect(0, 0, tw, th);
		case .Fill:
		{
		}
		case .Uniform:
		{
			let scale = Math.Min(width / tw, height / th);
			dest = Rect((width - tw * scale) * 0.5f, (height - th * scale) * 0.5f, tw * scale, th * scale);
		}
		case .UniformToFill:
		{
			let scale = Math.Max(width / tw, height / th);
			let sw = width / scale;
			let sh = height / scale;
			src = Rect((tw - sw) * 0.5f, (th - sh) * 0.5f, sw, sh);
		}
		}
		g.DrawTexture(texture, dest, src, tint);
	}
}
