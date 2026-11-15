namespace Juno;


using System;
using System.Interop;


[CRepr]
struct InputElementDescription
{
	const public c_uint cAppendAlignedElement = 0xFFFFFFFF;

	public c_char* mSemanticName;
	public c_uint mSemanticIndex;
	public PixelFormat mFormat;
	public c_uint mInputSlot;
	public c_uint mAlignedByteOffset;
	public InputClassification mInputSlotClass;
	public c_uint mInstanceDataStepRate;


	public this(c_char* semanticName, PixelFormat format, c_uint semanticIndex = 0, InputClassification inputSlotClass = .PerVertexData, c_uint alignedByteOffset = cAppendAlignedElement)
	{
		this.mSemanticName = semanticName;
		this.mSemanticIndex = semanticIndex;
		this.mFormat = format;
		this.mInputSlot = 0;
		this.mAlignedByteOffset = alignedByteOffset;
		this.mInputSlotClass = inputSlotClass;
		this.mInstanceDataStepRate = 0;
	}
}
