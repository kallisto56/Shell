namespace Shell.Layout;

using System;
using Shell.Core;
using Shell.Elements;

// Measure/arrange over the layout hierarchy of an ElementTree. Only dirty subtrees are processed (Invalidation.Layout).
// Layout runs in the Layout phase, reads Widget state only through bindings that already resolved, and never mutates the
// tree.
interface ILayoutProvider
{
	Vector2Size Measure(Element element, LayoutConstraints constraints);
	void Arrange(Element element, RectF finalRect);
}
