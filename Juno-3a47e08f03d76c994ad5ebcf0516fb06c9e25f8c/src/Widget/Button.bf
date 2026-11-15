namespace Juno;

using System;

class Button : Widget
{
	public String mText = new .() ~ delete _;
	public Font mFont;                  // null = Application.mDefaultFont
	public Color mTextColor = WidgetStyle.sText;

	public this(float x, float y, float width, float height, StringView text) : base(x, y, width, height)
	{
		this.mText.Set(text);
		this.bFocusable = true;
	}

	public override void OnKeyDown(ref KeyEventArgs args)
	{
		if (!args.bIsRepeat && (args.mKey == .Enter || args.mKey == .Space))
		{
			this.OnClick(default);
			this.mOnClick(this);
			args.bHandled = true;
		}
	}

	public override void OnDraw(Graphics g)
	{
		var background = WidgetStyle.sButton;
		if (!this.bEnabled) background = WidgetStyle.sButtonDisabled;
		else if (this.bPressed && this.bMouseOver) background = WidgetStyle.sButtonPressed;
		else if (this.bMouseOver) background = WidgetStyle.sButtonHover;

		g.FillRect(0, 0, this.mWidth, this.mHeight, background);
		g.DrawRect(this.mLocalRect, this.bHasFocus ? WidgetStyle.sFocusRing : WidgetStyle.sPanelBorder, 1);

		let font = (this.mFont != null) ? this.mFont : Application.sApp.mDefaultFont;
		if (font == null)
			return;
		let size = font.Measure(this.mText);
		g.DrawString(font, this.mText, Math.Round((this.mWidth - size.mX) * 0.5f), Math.Round((this.mHeight - size.mY) * 0.5f), this.mTextColor);
	}
}
