namespace Shell.Rendering;

using System;
using Shell.Core;
using Shell.Elements;

// What the element renderer needs from a GPU backend (implemented on top of Juno / the JunoFramework Graphics class in a
// later stage). The renderer walks a RenderListBuilder result and translates element properties into these calls; the
// backend knows nothing about widgets, bindings or elements.
interface IRenderBackend
{
	void BeginFrame(int width, int height, float dpiScale);
	void EndFrame();

	void PushTransform(float x, float y, float scaleX, float scaleY, float rotation, float pivotX, float pivotY);
	void PopTransform();
	void PushClipRect(RectF rect, float cornerRadius);
	void PopClip();

	// Isolated group: everything drawn until EndGroup is composited as one surface with the given opacity and effects.
	void BeginGroup(RectF bounds, float opacity, System.Collections.List<EffectDescriptor> effects);
	void EndGroup();
	// Backdrop group: effects are applied to the already drawn content behind `bounds` (blur-behind, acrylic).
	void BeginBackdrop(RectF bounds, System.Collections.List<EffectDescriptor> effects);
	void EndBackdrop();

	void FillShape(RectF bounds, Value fill, float cornerRadius);
	void StrokeShape(RectF bounds, Value stroke, float width, float cornerRadius);
	void DrawPath(StableId geometry, Value fill, Value stroke, float strokeWidth);
	void DrawText(StableId shapedText, float x, float y, Value color);
	void DrawImage(StableId image, RectF destination, RectF source, Value tint);
	void DrawVideoFrame(StableId video, RectF destination);
}
