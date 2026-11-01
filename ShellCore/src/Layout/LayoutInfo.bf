namespace Shell.Layout;

using System;
using Shell.Core;

// Layout parameters of one element, in its own slot of the *layout* hierarchy (which may differ from ownership).
struct LayoutInfo
{
	public LayoutMode mMode;                // how this element arranges its layout children
	public Axis mAxis;
	public float mSpacing;
	public SizeMode mWidthMode;
	public SizeMode mHeightMode;
	public float mWidth;                    // pixels, percent or fill weight depending on the mode
	public float mHeight;
	public float mMinWidth;
	public float mMinHeight;
	public float mMaxWidth;                 // 0 = unbounded
	public float mMaxHeight;
	public Thickness mMargin;
	public Thickness mPadding;
	public Alignment mHorizontalAlignment;
	public Alignment mVerticalAlignment;
	public int mGridRow;
	public int mGridColumn;
	public int mGridRowSpan;
	public int mGridColumnSpan;
}
