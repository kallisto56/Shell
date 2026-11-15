namespace Shell.Layout;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Reflection;

// Two pass layout (measure, then arrange) over the layout hierarchy of an ElementTree.
//
//   Measure  asks every element how large it wants to be inside the space its parent offers (unbounded = infinity).
//   Arrange  gives every element its final box. Positions are relative to the layout parent's top-left corner; the parent's padding
//            is already included, margins are applied by the element's own slot handling.
//
// Modes (how an element arranges its children): Absolute (every child at the content origin, offset by its Position), Anchor
// (children attached to the edges / centre of the content box; AnchorLeft + AnchorRight stretches, margins act as offsets),
// Stack (row or column with spacing; Fill children share the remaining space by weight), Grid (rows / columns of fixed, auto and
// star tracks; children placed by GridRow / GridColumn with spans).
//
// Size modes: Fixed (Width / Height), Auto (content), Fill (all offered space; weight in Stack), Percent (of the offered space).
// Alignment inside the slot: Start, Center, End, Stretch.
//
// Incremental: every element caches its measure (keyed by the offered size) and arrange (keyed by its slot) and carries dirty flags
// that Element.InvalidateLayout propagates to its layout ancestors; clean subtrees return immediately.
// Hidden elements (Visible = false or a false VisibleWhen) take no space.
class LayoutEngine
{
	public ITextMeasurer mText;
	public IImageMeasurer mImages;
	public int mMeasuredNodes;      // statistics of the last LayoutTree call
	public int mArrangedNodes;

	static bool IsUnbounded(float value) => value > 1e20f;
	static float Subtract(float value, float amount) => IsUnbounded(value) ? value : Math.Max(value - amount, 0);
	static bool SameRect(RectF a, RectF b) => a.mX == b.mX && a.mY == b.mY && a.mWidth == b.mWidth && a.mHeight == b.mHeight;

	public void LayoutTree(ElementTree tree, float width, float height)
	{
		mMeasuredNodes = 0;
		mArrangedNodes = 0;
		let root = tree.mRoot;
		if (root == null)
			return;

		if (tree.mLayoutWidth != width || tree.mLayoutHeight != height)
		{
			root.InvalidateLayout();
			tree.mLayoutWidth = width;
			tree.mLayoutHeight = height;
		}

		Measure(tree, root, width, height);
		// The skin root fills the widget unless it asks for a fixed size.
		Arrange(tree, root, RectF(0, 0, width, height), true, true);
	}

	// ---- Measure ----------------------------------------------------------------------------------------------------

	static float ExplicitSize(SizeMode mode, float value, float available)
	{
		switch (mode)
		{
		case .Fixed: return Math.Max(value, 0);
		case .Percent: return IsUnbounded(available) ? float.NaN : value * 0.01f * available;
		case .Fill: return IsUnbounded(available) ? float.NaN : available;
		default: return float.NaN;      // Auto
		}
	}

	void Measure(ElementTree tree, Element element, float availableW, float availableH)
	{
		if (!element.mIsVisible)
		{
			element.mMeasuredWidth = 0;
			element.mMeasuredHeight = 0;
			element.bMeasureDirty = false;
			return;
		}
		if (!element.bMeasureDirty && element.mLastAvailableWidth == availableW && element.mLastAvailableHeight == availableH)
			return;

		mMeasuredNodes++;
		let p = element.mLayoutParams;
		let innerW = Subtract(availableW, p.mMarginH);
		let innerH = Subtract(availableH, p.mMarginV);

		var w = ExplicitSize(p.mWidthMode, p.mWidth, innerW);
		var h = ExplicitSize(p.mHeightMode, p.mHeight, innerH);

		var boxW = w.IsNaN ? innerW : w;
		var boxH = h.IsNaN ? innerH : h;
		if (p.mMaxWidth > 0) boxW = Math.Min(boxW, p.mMaxWidth);
		if (p.mMaxHeight > 0) boxH = Math.Min(boxH, p.mMaxHeight);

		let content = MeasureContent(tree, element, p, Subtract(boxW, p.mPaddingH), Subtract(boxH, p.mPaddingV));
		if (w.IsNaN) w = content.mX + p.mPaddingH;
		if (h.IsNaN) h = content.mY + p.mPaddingV;

		w = Math.Max(w, p.mMinWidth);
		h = Math.Max(h, p.mMinHeight);
		if (p.mMaxWidth > 0) w = Math.Min(w, p.mMaxWidth);
		if (p.mMaxHeight > 0) h = Math.Min(h, p.mMaxHeight);

		element.mMeasuredWidth = w;
		element.mMeasuredHeight = h;
		element.mLastAvailableWidth = availableW;
		element.mLastAvailableHeight = availableH;
		element.bMeasureDirty = false;
	}

	PointF MeasureOwnContent(Element element, float availableW)
	{
		switch (element.mKind)
		{
		case .Text:
			if (mText == null)
				return default;
			let wrap = element.mProperties.Get(ElementTypes.sWrap).AsBool();
			return mText.MeasureText(element, (wrap && !IsUnbounded(availableW)) ? availableW : 0);
		case .Image, .Video:
			if (mImages == null)
				return default;
			return mImages.GetSourceSize(element.mProperties.Get(ElementTypes.sSource).AsString());
		case .Path:
			let geometry = element.GetPathGeometry();
			return (geometry != null) ? PointF(geometry.mBounds.mRight, geometry.mBounds.mBottom) : default;
		default:
			return default;
		}
	}

	PointF MeasureContent(ElementTree tree, Element element, LayoutParams p, float availableW, float availableH)
	{
		var size = MeasureOwnContent(element, availableW);

		let children = scope List<Element>();
		tree.GetLayoutChildren(element, children);
		var count = 0;
		for (let child in children)
		{
			if (child.mIsVisible)
				count++;
		}
		if (count == 0)
			return size;

		PointF inner = default;
		switch (p.mMode)
		{
		case .Absolute, .Anchor:
			for (let child in children)
			{
				if (!child.mIsVisible) continue;
				Measure(tree, child, availableW, availableH);
				let cp = child.mLayoutParams;
				inner.mX = Math.Max(inner.mX, child.mMeasuredWidth + cp.mMarginH);
				inner.mY = Math.Max(inner.mY, child.mMeasuredHeight + cp.mMarginV);
			}
		case .Stack:
		{
			let horizontal = (p.mAxis == .Horizontal);
			float main = 0;
			float cross = 0;
			var seen = 0;
			for (let child in children)
			{
				if (!child.mIsVisible) continue;
				Measure(tree, child, horizontal ? float.PositiveInfinity : availableW, horizontal ? availableH : float.PositiveInfinity);
				let cp = child.mLayoutParams;
				let outerW = child.mMeasuredWidth + cp.mMarginH;
				let outerH = child.mMeasuredHeight + cp.mMarginV;
				main += horizontal ? outerW : outerH;
				cross = Math.Max(cross, horizontal ? outerH : outerW);
				seen++;
			}
			main += p.mSpacing * (float)Math.Max(seen - 1, 0);
			inner = horizontal ? PointF(main, cross) : PointF(cross, main);
		}
		case .Grid:
		{
			let grid = ComputeGrid(tree, children, p, availableW, availableH);
			defer delete grid;
			inner = PointF(grid.mWidth, grid.mHeight);
		}
		}
		return PointF(Math.Max(size.mX, inner.mX), Math.Max(size.mY, inner.mY));
	}

	// ---- Grid -------------------------------------------------------------------------------------------------------------

	GridLayout ComputeGrid(ElementTree tree, List<Element> children, LayoutParams p, float contentW, float contentH)
	{
		let columns = scope List<GridTrack>();
		let rows = scope List<GridTrack>();
		GridTracks.Parse(p.mColumns, columns);
		GridTracks.Parse(p.mRows, rows);
		let nc = columns.Count;
		let nr = rows.Count;

		let grid = new GridLayout();
		for (int i < nc) grid.mColumns.Add((columns[i].mKind == .Fixed) ? columns[i].mValue : 0);
		for (int i < nr) grid.mRows.Add((rows[i].mKind == .Fixed) ? rows[i].mValue : 0);

		// Columns: auto and (when the width is unbounded) star tracks take the width of their widest single-span child.
		for (let child in children)
		{
			if (!child.mIsVisible) continue;
			let cp = child.mLayoutParams;
			let col = Math.Min((int)cp.mGridColumn, nc - 1);
			let kind = columns[col].mKind;
			if (cp.mColumnSpan != 1 || kind == .Fixed || (kind == .Star && !IsUnbounded(contentW)))
				continue;
			let row = Math.Min((int)cp.mGridRow, nr - 1);
			Measure(tree, child, float.PositiveInfinity, (rows[row].mKind == .Fixed) ? rows[row].mValue : float.PositiveInfinity);
			grid.mColumns[col] = Math.Max(grid.mColumns[col], child.mMeasuredWidth + cp.mMarginH);
		}
		if (!IsUnbounded(contentW))
		{
			float used = 0;
			float weights = 0;
			for (int i < nc)
			{
				if (columns[i].mKind == .Star) weights += columns[i].mValue;
				else used += grid.mColumns[i];
			}
			let remaining = Math.Max(contentW - used, 0);
			for (int i < nc)
			{
				if (columns[i].mKind == .Star)
					grid.mColumns[i] = (weights > 0) ? remaining * columns[i].mValue / weights : 0;
			}
		}

		// Rows: now that column widths are known, children can be measured with their real width (text wraps correctly).
		for (let child in children)
		{
			if (!child.mIsVisible) continue;
			let cp = child.mLayoutParams;
			let col = Math.Min((int)cp.mGridColumn, nc - 1);
			let row = Math.Min((int)cp.mGridRow, nr - 1);
			let kind = rows[row].mKind;
			if (cp.mRowSpan != 1 || kind == .Fixed || (kind == .Star && !IsUnbounded(contentH)))
				continue;
			Measure(tree, child, grid.ColumnsWidth(col, cp.mColumnSpan), float.PositiveInfinity);
			grid.mRows[row] = Math.Max(grid.mRows[row], child.mMeasuredHeight + cp.mMarginV);
		}
		if (!IsUnbounded(contentH))
		{
			float used = 0;
			float weights = 0;
			for (int i < nr)
			{
				if (rows[i].mKind == .Star) weights += rows[i].mValue;
				else used += grid.mRows[i];
			}
			let remaining = Math.Max(contentH - used, 0);
			for (int i < nr)
			{
				if (rows[i].mKind == .Star)
					grid.mRows[i] = (weights > 0) ? remaining * rows[i].mValue / weights : 0;
			}
		}
		return grid;
	}

	// ---- Arrange ----------------------------------------------------------------------------------------------------------

	static float ArrangedSize(SizeMode mode, float value, float available, float measured, bool stretch)
	{
		switch (mode)
		{
		case .Fixed: return Math.Max(value, 0);
		case .Percent: return value * 0.01f * available;
		case .Fill: return available;
		default: return stretch ? available : measured;
		}
	}

	void Arrange(ElementTree tree, Element element, RectF slot, bool forceFillW, bool forceFillH)
	{
		if (!element.mIsVisible)
		{
			element.mArranged = RectF(slot.mX, slot.mY, 0, 0);
			element.bArrangeDirty = false;
			return;
		}
		if (!element.bArrangeDirty && element.bHasSlot && SameRect(element.mLastSlot, slot))
			return;

		mArrangedNodes++;
		let p = element.mLayoutParams;
		let availableW = Math.Max(slot.mWidth - p.mMarginH, 0);
		let availableH = Math.Max(slot.mHeight - p.mMarginV, 0);

		var w = ArrangedSize(p.mWidthMode, p.mWidth, availableW, element.mMeasuredWidth, forceFillW || p.mHorizontal == .Stretch);
		var h = ArrangedSize(p.mHeightMode, p.mHeight, availableH, element.mMeasuredHeight, forceFillH || p.mVertical == .Stretch);
		w = Math.Max(w, p.mMinWidth);
		h = Math.Max(h, p.mMinHeight);
		if (p.mMaxWidth > 0) w = Math.Min(w, p.mMaxWidth);
		if (p.mMaxHeight > 0) h = Math.Min(h, p.mMaxHeight);

		var x = slot.mX + p.mMargin.mLeft;
		var y = slot.mY + p.mMargin.mTop;
		if (!forceFillW)
		{
			if (p.mHorizontal == .Center) x += (availableW - w) * 0.5f;
			else if (p.mHorizontal == .End) x += availableW - w;
		}
		if (!forceFillH)
		{
			if (p.mVertical == .Center) y += (availableH - h) * 0.5f;
			else if (p.mVertical == .End) y += availableH - h;
		}

		let arranged = RectF(x, y, w, h);
		if (!element.bHasSlot || !SameRect(arranged, element.mArranged))
		{
			element.mArranged = arranged;
			element.InvalidateState();
		}

		ArrangeChildren(tree, element, p, w, h);
		element.mLastSlot = slot;
		element.bHasSlot = true;
		element.bArrangeDirty = false;
	}

	void ArrangeChildren(ElementTree tree, Element element, LayoutParams p, float w, float h)
	{
		let children = scope List<Element>();
		tree.GetLayoutChildren(element, children);
		if (children.Count == 0)
			return;

		let cx = p.mPadding.mLeft;
		let cy = p.mPadding.mTop;
		let cw = Math.Max(w - p.mPaddingH, 0);
		let ch = Math.Max(h - p.mPaddingV, 0);

		switch (p.mMode)
		{
		case .Absolute:
			for (let child in children)
				Arrange(tree, child, RectF(cx, cy, cw, ch), false, false);

		case .Anchor:
			for (let child in children)
				ArrangeAnchored(tree, child, cx, cy, cw, ch);

		case .Stack:
			ArrangeStack(tree, children, p, cx, cy, cw, ch);

		case .Grid:
		{
			let grid = ComputeGrid(tree, children, p, cw, ch);
			defer delete grid;
			let nc = grid.mColumns.Count;
			let nr = grid.mRows.Count;
			for (let child in children)
			{
				let cp = child.mLayoutParams;
				let col = Math.Min((int)cp.mGridColumn, nc - 1);
				let row = Math.Min((int)cp.mGridRow, nr - 1);
				Arrange(tree, child, RectF(cx + grid.ColumnStart(col), cy + grid.RowStart(row),
					grid.ColumnsWidth(col, cp.mColumnSpan), grid.RowsHeight(row, cp.mRowSpan)), false, false);
			}
		}
		}
	}

	void ArrangeAnchored(ElementTree tree, Element child, float cx, float cy, float cw, float ch)
	{
		let cp = child.mLayoutParams;
		let outerW = child.mMeasuredWidth + cp.mMarginH;
		let outerH = child.mMeasuredHeight + cp.mMarginV;

		float sx; float sw; bool stretchW = false;
		if (cp.bAnchorLeft && cp.bAnchorRight) { sx = cx; sw = cw; stretchW = true; }
		else if (cp.bAnchorRight) { sx = cx + cw - outerW; sw = outerW; }
		else if (cp.bAnchorLeft) { sx = cx; sw = outerW; }
		else { sx = cx + (cw - outerW) * 0.5f; sw = outerW; }

		float sy; float sh; bool stretchH = false;
		if (cp.bAnchorTop && cp.bAnchorBottom) { sy = cy; sh = ch; stretchH = true; }
		else if (cp.bAnchorBottom) { sy = cy + ch - outerH; sh = outerH; }
		else if (cp.bAnchorTop) { sy = cy; sh = outerH; }
		else { sy = cy + (ch - outerH) * 0.5f; sh = outerH; }

		Arrange(tree, child, RectF(sx, sy, sw, sh), stretchW, stretchH);
	}

	void ArrangeStack(ElementTree tree, List<Element> children, LayoutParams p, float cx, float cy, float cw, float ch)
	{
		let horizontal = (p.mAxis == .Horizontal);
		float consumed = 0;
		float weights = 0;
		var visible = 0;
		for (let child in children)
		{
			if (!child.mIsVisible) continue;
			visible++;
			let cp = child.mLayoutParams;
			let mode = horizontal ? cp.mWidthMode : cp.mHeightMode;
			let margin = horizontal ? cp.mMarginH : cp.mMarginV;
			if (mode == .Fill)
			{
				let value = horizontal ? cp.mWidth : cp.mHeight;
				weights += (value > 0) ? value : 1;
				consumed += margin;
			}
			else
			{
				consumed += horizontal ? child.mMeasuredWidth + margin : child.mMeasuredHeight + margin;
			}
		}
		consumed += p.mSpacing * (float)Math.Max(visible - 1, 0);
		let remaining = Math.Max((horizontal ? cw : ch) - consumed, 0);

		var position = horizontal ? cx : cy;
		for (let child in children)
		{
			if (!child.mIsVisible)
			{
				Arrange(tree, child, RectF(cx, cy, 0, 0), false, false);
				continue;
			}
			let cp = child.mLayoutParams;
			let mode = horizontal ? cp.mWidthMode : cp.mHeightMode;
			let margin = horizontal ? cp.mMarginH : cp.mMarginV;
			float size;
			if (mode == .Fill)
			{
				let value = horizontal ? cp.mWidth : cp.mHeight;
				size = ((weights > 0) ? remaining * ((value > 0) ? value : 1) / weights : 0) + margin;
			}
			else
			{
				size = horizontal ? child.mMeasuredWidth + margin : child.mMeasuredHeight + margin;
			}
			Arrange(tree, child, horizontal ? RectF(position, cy, size, ch) : RectF(cx, position, cw, size), false, false);
			position += size + p.mSpacing;
		}
	}
}
