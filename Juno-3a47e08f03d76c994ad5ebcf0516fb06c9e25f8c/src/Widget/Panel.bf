namespace Juno;

using System;

class Panel : Widget
{
	public Color mColor = WidgetStyle.sPanelBackground;
	public Color mBorderColor = WidgetStyle.sPanelBorder;
	public float mBorderThickness = 1;

	public this(float x, float y, float width, float height) : base(x, y, width, height)
	{
		this.bClipChildren = true;
	}

	public override bool HitTest(float x, float y)
	{
		// A panel swallows the mouse so the 3D scene below does not react to clicks on the UI.
		return x >= 0 && y >= 0 && x < this.mWidth && y < this.mHeight;
	}

	public override void OnDraw(Graphics g)
	{
		g.FillRect(0, 0, this.mWidth, this.mHeight, this.mColor);
		if (this.mBorderThickness > 0)
			g.DrawRect(this.mLocalRect, this.mBorderColor, this.mBorderThickness);
	}
}
