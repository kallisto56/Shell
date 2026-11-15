namespace Shell.Elements;

using System;
using Shell.Core;
using Shell.Reflection;

// Property descriptors of all element types (process-wide singletons shared by every context).
//
//   Element  (Container)  visibility, opacity, transform, clipping, and the layout properties
//   Vector                Fill, Stroke, StrokeWidth        Shape: ShapeKind, CornerRadius        Path: PathData, Stretch
//   Media                 Source, Tint, Stretch            Image          Video: Playing, Loop
//   Text                  Text, FontFamily, FontSize, Color, TextAlign, Wrap
//
// Layout properties (all bindable, invalidate layout):
//   LayoutMode (Absolute | Stack | Grid | Anchor) and Axis / Spacing / Rows / Columns describe how an element arranges its children.
//   WidthMode / HeightMode (Auto | Fixed | Fill | Percent) with Width / Height, Min/Max sizes, Margin and Padding (Rect value:
//   left, top, right, bottom), HorizontalAlignment / VerticalAlignment, and per-child placement: GridRow / GridColumn / RowSpan /
//   ColumnSpan and the Anchor* flags. Position is an offset applied after layout.
static class ElementTypes
{
	static public TypeDescriptor sElement;
	static public TypeDescriptor sVector;
	static public TypeDescriptor sShape;
	static public TypeDescriptor sPath;
	static public TypeDescriptor sMedia;
	static public TypeDescriptor sImage;
	static public TypeDescriptor sVideo;
	static public TypeDescriptor sText;

	// Element
	static public PropertyDescriptor sVisible;
	static public PropertyDescriptor sOpacity;
	static public PropertyDescriptor sPosition;
	static public PropertyDescriptor sScale;
	static public PropertyDescriptor sRotation;
	static public PropertyDescriptor sPivot;
	static public PropertyDescriptor sClipToBounds;
	static public PropertyDescriptor sLayoutMode;
	static public PropertyDescriptor sAxis;
	static public PropertyDescriptor sSpacing;
	static public PropertyDescriptor sRows;
	static public PropertyDescriptor sColumns;
	static public PropertyDescriptor sWidthMode;
	static public PropertyDescriptor sHeightMode;
	static public PropertyDescriptor sWidth;
	static public PropertyDescriptor sHeight;
	static public PropertyDescriptor sMinWidth;
	static public PropertyDescriptor sMinHeight;
	static public PropertyDescriptor sMaxWidth;
	static public PropertyDescriptor sMaxHeight;
	static public PropertyDescriptor sMargin;
	static public PropertyDescriptor sPadding;
	static public PropertyDescriptor sHorizontalAlignment;
	static public PropertyDescriptor sVerticalAlignment;
	static public PropertyDescriptor sAnchorLeft;
	static public PropertyDescriptor sAnchorTop;
	static public PropertyDescriptor sAnchorRight;
	static public PropertyDescriptor sAnchorBottom;
	static public PropertyDescriptor sGridRow;
	static public PropertyDescriptor sGridColumn;
	static public PropertyDescriptor sRowSpan;
	static public PropertyDescriptor sColumnSpan;

	// Vector / Shape / Path
	static public PropertyDescriptor sFill;
	static public PropertyDescriptor sStroke;
	static public PropertyDescriptor sStrokeWidth;
	static public PropertyDescriptor sShapeKind;
	static public PropertyDescriptor sCornerRadius;
	static public PropertyDescriptor sPathData;
	static public PropertyDescriptor sPathStretch;

	// Media (Image / Video)
	static public PropertyDescriptor sSource;
	static public PropertyDescriptor sTint;
	static public PropertyDescriptor sStretch;
	static public PropertyDescriptor sPlaying;
	static public PropertyDescriptor sLoop;

	// Text
	static public PropertyDescriptor sTextContent;
	static public PropertyDescriptor sFontFamily;
	static public PropertyDescriptor sFontSize;
	static public PropertyDescriptor sTextColor;
	static public PropertyDescriptor sTextAlign;
	static public PropertyDescriptor sWrap;

	static PropertyDescriptor Add(TypeDescriptor type, StringView name, ValueKind kind, Value defaultValue, Invalidation invalidates, StringView enumType = default,
		PropertyFlags flags = .Serialized | .Bindable | .Animatable | .Styleable)
	{
		return type.AddProperty(new PropertyDescriptor(name, kind) { mDefault = defaultValue, mInvalidates = invalidates, mFlags = flags, mEnumType = enumType });
	}

	static public bool Register(RuntimeContext context)
	{
		if (sElement == null)
			Create();
		bool bOk = true;
		bOk &= context.mTypes.Register(sElement, context.mDiagnostics, false);
		bOk &= context.mTypes.Register(sVector, context.mDiagnostics, false);
		bOk &= context.mTypes.Register(sShape, context.mDiagnostics, false);
		bOk &= context.mTypes.Register(sPath, context.mDiagnostics, false);
		bOk &= context.mTypes.Register(sMedia, context.mDiagnostics, false);
		bOk &= context.mTypes.Register(sImage, context.mDiagnostics, false);
		bOk &= context.mTypes.Register(sVideo, context.mDiagnostics, false);
		bOk &= context.mTypes.Register(sText, context.mDiagnostics, false);
		return bOk;
	}

	static public TypeDescriptor TypeFor(ElementKind kind)
	{
		switch (kind)
		{
		case .Shape: return sShape;
		case .Path: return sPath;
		case .Text: return sText;
		case .Image: return sImage;
		case .Video: return sVideo;
		default: return sElement;
		}
	}

	static void Create()
	{
		sElement = new TypeDescriptor("Element", .Element);
		let t = sElement;

		sVisible = Add(t, "Visible", .Bool, Value.FromBool(true), .Layout | .Structure | .Transform | .Visual);
		sOpacity = Add(t, "Opacity", .Float, Value.FromFloat(1), .Transform | .Visual);
		sPosition = Add(t, "Position", .Vector2, Value.FromVector2(0, 0), .Transform | .Visual);
		sScale = Add(t, "Scale", .Vector2, Value.FromVector2(1, 1), .Transform | .Visual);
		sRotation = Add(t, "Rotation", .Float, Value.FromFloat(0), .Transform | .Visual);
		sPivot = Add(t, "Pivot", .Vector2, Value.FromVector2(0.5f, 0.5f), .Transform | .Visual, default, .Serialized | .Bindable);
		sClipToBounds = Add(t, "ClipToBounds", .Bool, Value.FromBool(false), .Transform | .Visual, default, .Serialized | .Bindable);

		sLayoutMode = Add(t, "LayoutMode", .Enum, Value.FromEnum("Absolute"), .Layout, "LayoutMode", .Serialized | .Bindable);
		sAxis = Add(t, "Axis", .Enum, Value.FromEnum("Vertical"), .Layout, "Axis", .Serialized | .Bindable);
		sSpacing = Add(t, "Spacing", .Float, Value.FromFloat(0), .Layout);
		sRows = Add(t, "Rows", .String, default, .Layout, default, .Serialized | .Bindable);
		sColumns = Add(t, "Columns", .String, default, .Layout, default, .Serialized | .Bindable);
		sWidthMode = Add(t, "WidthMode", .Enum, Value.FromEnum("Auto"), .Layout, "SizeMode", .Serialized | .Bindable);
		sHeightMode = Add(t, "HeightMode", .Enum, Value.FromEnum("Auto"), .Layout, "SizeMode", .Serialized | .Bindable);
		sWidth = Add(t, "Width", .Float, Value.FromFloat(0), .Layout);
		sHeight = Add(t, "Height", .Float, Value.FromFloat(0), .Layout);
		sMinWidth = Add(t, "MinWidth", .Float, Value.FromFloat(0), .Layout);
		sMinHeight = Add(t, "MinHeight", .Float, Value.FromFloat(0), .Layout);
		sMaxWidth = Add(t, "MaxWidth", .Float, Value.FromFloat(0), .Layout);
		sMaxHeight = Add(t, "MaxHeight", .Float, Value.FromFloat(0), .Layout);
		sMargin = Add(t, "Margin", .Rect, Value.FromRect(0, 0, 0, 0), .Layout);
		sPadding = Add(t, "Padding", .Rect, Value.FromRect(0, 0, 0, 0), .Layout);
		sHorizontalAlignment = Add(t, "HorizontalAlignment", .Enum, Value.FromEnum("Start"), .Layout, "Alignment", .Serialized | .Bindable);
		sVerticalAlignment = Add(t, "VerticalAlignment", .Enum, Value.FromEnum("Start"), .Layout, "Alignment", .Serialized | .Bindable);
		sAnchorLeft = Add(t, "AnchorLeft", .Bool, Value.FromBool(false), .Layout, default, .Serialized | .Bindable);
		sAnchorTop = Add(t, "AnchorTop", .Bool, Value.FromBool(false), .Layout, default, .Serialized | .Bindable);
		sAnchorRight = Add(t, "AnchorRight", .Bool, Value.FromBool(false), .Layout, default, .Serialized | .Bindable);
		sAnchorBottom = Add(t, "AnchorBottom", .Bool, Value.FromBool(false), .Layout, default, .Serialized | .Bindable);
		sGridRow = Add(t, "GridRow", .Int, Value.FromInt(0), .Layout, default, .Serialized | .Bindable);
		sGridColumn = Add(t, "GridColumn", .Int, Value.FromInt(0), .Layout, default, .Serialized | .Bindable);
		sRowSpan = Add(t, "RowSpan", .Int, Value.FromInt(1), .Layout, default, .Serialized | .Bindable);
		sColumnSpan = Add(t, "ColumnSpan", .Int, Value.FromInt(1), .Layout, default, .Serialized | .Bindable);

		let none = Value.FromColor(0, 0, 0, 0);
		let white = Value.FromColor(1, 1, 1, 1);

		sVector = new TypeDescriptor("Vector", .Element, t);
		sFill = Add(sVector, "Fill", .Color, none, .Visual);
		sStroke = Add(sVector, "Stroke", .Color, none, .Visual);
		sStrokeWidth = Add(sVector, "StrokeWidth", .Float, Value.FromFloat(1), .Geometry | .Visual);

		sShape = new TypeDescriptor("Shape", .Element, sVector);
		sShapeKind = Add(sShape, "ShapeKind", .Enum, Value.FromEnum("Rectangle"), .Geometry | .Visual, "ShapeKind", .Serialized | .Bindable);
		sCornerRadius = Add(sShape, "CornerRadius", .Float, Value.FromFloat(0), .Geometry | .Visual);

		sPath = new TypeDescriptor("Path", .Element, sVector);
		sPathData = Add(sPath, "PathData", .String, default, .Geometry | .Layout | .Visual, default, .Serialized | .Bindable);
		sPathStretch = Add(sPath, "Stretch", .Enum, Value.FromEnum("None"), .Geometry | .Visual, "ImageStretch", .Serialized | .Bindable);

		sMedia = new TypeDescriptor("Media", .Element, t);
		sSource = Add(sMedia, "Source", .String, default, .Layout | .Visual, default, .Serialized | .Bindable);
		sTint = Add(sMedia, "Tint", .Color, white, .Visual);
		sStretch = Add(sMedia, "Stretch", .Enum, Value.FromEnum("Uniform"), .Visual, "ImageStretch", .Serialized | .Bindable);
		sImage = new TypeDescriptor("Image", .Element, sMedia);
		sVideo = new TypeDescriptor("Video", .Element, sMedia);
		sPlaying = Add(sVideo, "Playing", .Bool, Value.FromBool(true), .Visual, default, .Serialized | .Bindable);
		sLoop = Add(sVideo, "Loop", .Bool, Value.FromBool(true), .Visual, default, .Serialized | .Bindable);

		sText = new TypeDescriptor("Text", .Element, t);
		sTextContent = Add(sText, "Text", .String, default, .Layout | .Text | .Visual, default, .Serialized | .Bindable);
		sFontFamily = Add(sText, "FontFamily", .String, Value.FromString("Segoe UI"), .Layout | .Text | .Visual, default, .Serialized | .Bindable | .Styleable);
		sFontSize = Add(sText, "FontSize", .Float, Value.FromFloat(14), .Layout | .Text | .Visual);
		sTextColor = Add(sText, "Color", .Color, white, .Visual);
		sTextAlign = Add(sText, "TextAlign", .Enum, Value.FromEnum("Left"), .Visual, "TextHorizontalAlign", .Serialized | .Bindable);
		sWrap = Add(sText, "Wrap", .Bool, Value.FromBool(false), .Layout | .Text | .Visual, default, .Serialized | .Bindable);
	}
}
