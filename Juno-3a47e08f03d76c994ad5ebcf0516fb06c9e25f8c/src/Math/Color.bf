namespace Juno;


using System;
using System.Diagnostics;


[CRepr]
struct Color
{
	const public Color cWhite = Color(255, 255, 255, 255);
	const public Color cBlack = Color(0, 0, 0, 255);
	const public Color cTransparent = Color(0, 0, 0, 0);
	const public Color cRed = Color(255, 64, 64, 255);
	const public Color cGreen = Color(64, 220, 96, 255);
	const public Color cBlue = Color(64, 128, 255, 255);
	const public Color cYellow = Color(255, 220, 64, 255);
	const public Color cCyan = Color(64, 220, 255, 255);
	const public Color cMagenta = Color(255, 96, 220, 255);
	const public Color cOrange = Color(255, 150, 48, 255);
	const public Color cGray = Color(128, 128, 128, 255);
	const public Color cDarkGray = Color(40, 42, 50, 255);

	public uint8[4] mValues;


	public uint8 mR
	{
		[Inline] get => this.mValues[0];
		[Inline] set mut => this.mValues[0] = value;
	}

	public uint8 mG
	{
		[Inline] get => this.mValues[1];
		[Inline] set mut => this.mValues[1] = value;
	}

	public uint8 mB
	{
		[Inline] get => this.mValues[2];
		[Inline] set mut => this.mValues[2] = value;
	}

	public uint8 mA
	{
		[Inline] get => this.mValues[3];
		[Inline] set mut => this.mValues[3] = value;
	}


	public this()
	{
		this.mValues = uint8[4](1, 0, 0, 0);
	}


	public this(uint8 r, uint8 g, uint8 b, uint8 a)
	{
		this.mValues = uint8[4](r,g,b,a);
	}


	public this(Color color, uint8 a)
	{
		this.mValues = uint8[4](color.mR, color.mG, color.mB, a);
	}


	public this(float r, float g, float b, float a)
	{
		this.mValues = uint8[4](
			uint8(r * 255),
			uint8(g * 255),
			uint8(b * 255),
			uint8(a * 255),
		);
	}


	override public void ToString(String buffer)
	{
		buffer.AppendF("Color({}, {}, {}, {})", this.mR, this.mG, this.mB, this.mA);
	}


	static public Color Lerp(Color lhs, Color rhs, float alpha)
	{
		return Color(
			Math.Lerp(lhs.mR, rhs.mR, alpha),
			Math.Lerp(lhs.mG, rhs.mG, alpha),
			Math.Lerp(lhs.mB, rhs.mB, alpha),
			Math.Lerp(lhs.mA, rhs.mA, alpha)
		);
	}


	[Inline]
	public uint32 ToUInt32()
	{
		#unwarn
		return *(uint32*)(void*)&this.mValues;
	}


	public void ToUInt32(out uint8 r, out uint8 g, out uint8 b, out uint8 a)
	{
		r = this.mR;
		g = this.mG;
		b = this.mB;
		a = this.mA;
	}


	static public Color FromUInt32(uint32 rgba)
	{
		return Color(
			uint8(rgba >> 24),
			uint8((rgba & 0x00FF0000) >> 16),
			uint8((rgba & 0x0000FF00) >> 8),
			uint8(rgba & 0x000000FF)
		);
	}


	static public implicit Color operator * (Color a, Color b)
	{
		return Color(
			(uint8)(((int32)a.mR * (int32)b.mR) / 255),
			(uint8)(((int32)a.mG * (int32)b.mG) / 255),
			(uint8)(((int32)a.mB * (int32)b.mB) / 255),
			(uint8)(((int32)a.mA * (int32)b.mA) / 255)
		);
	}
}