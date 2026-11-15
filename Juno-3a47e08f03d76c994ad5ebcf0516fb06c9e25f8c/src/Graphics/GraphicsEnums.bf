namespace Juno;

using System;

enum BlendMode
{
	case Opaque;
	case Alpha;             // src.rgb * src.a + dst.rgb * (1 - src.a)
	case Additive;          // src.rgb * src.a + dst.rgb
	case Premultiplied;     // src.rgb + dst.rgb * (1 - src.a)

	public const int cCount = 4;
}

enum DepthMode
{
	case None;              // no test, no write (UI, 2D)
	case ReadWrite;         // LessEqual test + write (3D)
	case ReadOnly;          // LessEqual test, no write (transparent 3D)

	public const int cCount = 3;
}

enum SamplerKind
{
	case PointClamp;
	case LinearClamp;
	case PointWrap;
	case LinearWrap;

	public const int cCount = 4;
}

enum TextAlign
{
	case Left;
	case Center;
	case Right;
}
