namespace Shell.Layout;

using System;

struct LayoutConstraints
{
	public float mMinWidth;
	public float mMinHeight;
	public float mMaxWidth;     // float.MaxValue = unbounded
	public float mMaxHeight;
}
