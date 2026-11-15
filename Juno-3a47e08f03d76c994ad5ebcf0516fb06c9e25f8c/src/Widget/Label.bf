namespace Juno;

using System;

class Label : Widget
{
	public String mText = new .() ~ delete _;
	public Font mFont;                  // null = Application.mDefaultFont
	public Color mColor = WidgetStyle.sText;
	public TextAlign mAlign = .Left;
	public bool bWrap;                  // wrap at the widget width
	public bool bAutoSize = true;       // size follows the text (not while wrapping)

	public this(float x, float y, StringView text) : base(x, y, 0, 0)
	{
		this.bHitTestVisible = false;
		this.SetText(text);
	}

	Font GetFont()
	{
		return (this.mFont != null) ? this.mFont : Application.sApp.mDefaultFont;
	}

	public void SetText(StringView text)
	{
		if (this.mText.Equals(text))
			return;
		this.mText.Set(text);
		this.UpdateSize();
	}

	public void UpdateSize()
	{
		let font = this.GetFont();
		if (!this.bAutoSize || this.bWrap || font == null)
			return;
		let size = font.Measure(this.mText);
		this.mWidth = size.mX;
		this.mHeight = size.mY;
	}

	public override void OnDraw(Graphics g)
	{
		let font = this.GetFont();
		if (font == null)
			return;
		g.DrawString(font, this.mText, 0, 0, this.mColor, this.mAlign, this.bWrap ? this.mWidth : 0);
	}
}
