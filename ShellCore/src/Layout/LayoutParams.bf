namespace Shell.Layout;

using System;
using Shell.Core;
using Shell.Elements;
using Shell.Reflection;

// Snapshot of the layout properties of one element, parsed once per change instead of once per layout pass.
struct LayoutParams
{
	public LayoutMode mMode;
	public Axis mAxis;
	public float mSpacing;
	public SizeMode mWidthMode;
	public SizeMode mHeightMode;
	public float mWidth;
	public float mHeight;
	public float mMinWidth;
	public float mMinHeight;
	public float mMaxWidth;             // 0 = unbounded
	public float mMaxHeight;
	public Thickness mMargin;
	public Thickness mPadding;
	public float mMarginH;              // left + right
	public float mMarginV;              // top + bottom
	public float mPaddingH;
	public float mPaddingV;
	public Alignment mHorizontal;
	public Alignment mVertical;
	public bool bAnchorLeft;
	public bool bAnchorTop;
	public bool bAnchorRight;
	public bool bAnchorBottom;
	public int32 mGridRow;
	public int32 mGridColumn;
	public int32 mRowSpan;
	public int32 mColumnSpan;
	public StringView mRows;
	public StringView mColumns;

	static T ReadEnum<T>(Element element, PropertyDescriptor property, T fallback) where T : enum
	{
		let name = element.mProperties.Get(property).AsString();
		if (Enum.Parse<T>(name) case .Ok(let value))
			return value;
		return fallback;
	}

	static Thickness ReadThickness(Element element, PropertyDescriptor property)
	{
		let v = element.mProperties.Get(property);
		return Thickness(v.mX, v.mY, v.mZ, v.mW);
	}

	static public LayoutParams From(Element e)
	{
		let p = e.mProperties;
		LayoutParams result = default;
		result.mMode = ReadEnum(e, ElementTypes.sLayoutMode, LayoutMode.Absolute);
		result.mAxis = ReadEnum(e, ElementTypes.sAxis, Axis.Vertical);
		result.mSpacing = (float)p.Get(ElementTypes.sSpacing).AsFloat();
		result.mWidthMode = ReadEnum(e, ElementTypes.sWidthMode, SizeMode.Auto);
		result.mHeightMode = ReadEnum(e, ElementTypes.sHeightMode, SizeMode.Auto);
		result.mWidth = (float)p.Get(ElementTypes.sWidth).AsFloat();
		result.mHeight = (float)p.Get(ElementTypes.sHeight).AsFloat();
		result.mMinWidth = (float)p.Get(ElementTypes.sMinWidth).AsFloat();
		result.mMinHeight = (float)p.Get(ElementTypes.sMinHeight).AsFloat();
		result.mMaxWidth = (float)p.Get(ElementTypes.sMaxWidth).AsFloat();
		result.mMaxHeight = (float)p.Get(ElementTypes.sMaxHeight).AsFloat();
		result.mMargin = ReadThickness(e, ElementTypes.sMargin);
		result.mPadding = ReadThickness(e, ElementTypes.sPadding);
		result.mMarginH = result.mMargin.mLeft + result.mMargin.mRight;
		result.mMarginV = result.mMargin.mTop + result.mMargin.mBottom;
		result.mPaddingH = result.mPadding.mLeft + result.mPadding.mRight;
		result.mPaddingV = result.mPadding.mTop + result.mPadding.mBottom;
		result.mHorizontal = ReadEnum(e, ElementTypes.sHorizontalAlignment, Alignment.Start);
		result.mVertical = ReadEnum(e, ElementTypes.sVerticalAlignment, Alignment.Start);
		result.bAnchorLeft = p.Get(ElementTypes.sAnchorLeft).AsBool();
		result.bAnchorTop = p.Get(ElementTypes.sAnchorTop).AsBool();
		result.bAnchorRight = p.Get(ElementTypes.sAnchorRight).AsBool();
		result.bAnchorBottom = p.Get(ElementTypes.sAnchorBottom).AsBool();
		result.mGridRow = (int32)Math.Max(p.Get(ElementTypes.sGridRow).AsInt(), 0);
		result.mGridColumn = (int32)Math.Max(p.Get(ElementTypes.sGridColumn).AsInt(), 0);
		result.mRowSpan = (int32)Math.Max(p.Get(ElementTypes.sRowSpan).AsInt(1), 1);
		result.mColumnSpan = (int32)Math.Max(p.Get(ElementTypes.sColumnSpan).AsInt(1), 1);
		result.mRows = p.Get(ElementTypes.sRows).AsString();
		result.mColumns = p.Get(ElementTypes.sColumns).AsString();
		return result;
	}
}
