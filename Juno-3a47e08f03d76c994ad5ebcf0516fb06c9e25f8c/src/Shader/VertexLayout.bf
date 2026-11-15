namespace Juno;

using System;
using System.Collections;
using System.Interop;

// Describes the per-vertex memory layout used to create an input layout for a ShaderProgram.
class VertexLayout
{
	public List<InputElementDescription> mElements = new .() ~ delete _;
	public c_uint mStride;

	public this(c_uint stride)
	{
		this.mStride = stride;
	}

	public VertexLayout Add(c_char* semantic, PixelFormat format, c_uint offset, c_uint semanticIndex = 0)
	{
		this.mElements.Add(InputElementDescription(semantic, format, semanticIndex, .PerVertexData, offset));
		return this;
	}

	public VertexLayout AddInstanced(c_char* semantic, PixelFormat format, c_uint offset, c_uint semanticIndex = 0)
	{
		this.mElements.Add(InputElementDescription(semantic, format, semanticIndex, .PerInstanceData, offset));
		return this;
	}
}
