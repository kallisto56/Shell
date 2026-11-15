namespace Juno;

using System;
using System.Interop;

[CRepr]
enum BindFlags : c_uint
{
	case None = 0;
	case VertexBuffer = 0x1;
	case IndexBuffer = 0x2;
	case ConstantBuffer = 0x4;
	case ShaderResource = 0x8;
	case StreamOutput = 0x10;
	case RenderTarget = 0x20;
	case DepthStencil = 0x40;
	case UnorderedAccess = 0x80;
}
