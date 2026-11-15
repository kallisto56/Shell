namespace Juno;


using System;


[CRepr]
struct Vertex
{
	public float mX;
	public float mY;
	public float mZ;
	public float mU;
	public float mV;
	public Color mColor;


	public this(float x, float y, float z, float u, float v, Color color)
	{
		this.mX = x;
		this.mY = y;
		this.mZ = z;
		this.mU = u;
		this.mV = v;
		this.mColor = color;
	}

	static public VertexLayout CreateLayout()
	{
		let layout = new VertexLayout(sizeof(Vertex));
		layout.Add("POSITION", .R32G32B32_Float, 0);
		layout.Add("TEXCOORD", .R32G32_Float, 12);
		layout.Add("COLOR", .R8G8B8A8_UNorm, 20);
		return layout;
	}
}
