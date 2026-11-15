namespace Juno;


using System;
using System.Diagnostics;
using System.Interop;


[CRepr]
struct JunoImage
{
	public c_uchar* mPixels = null;
	public c_uint mWidth = 0;
	public c_uint mHeight = 0;
	public c_uint mChannels = 0;
	public c_uint mRowPitch = 0;
	public PixelFormat mFormat = .Unknown;
}
