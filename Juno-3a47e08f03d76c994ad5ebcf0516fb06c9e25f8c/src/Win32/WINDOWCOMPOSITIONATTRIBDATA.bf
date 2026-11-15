namespace Juno;

using System;
using System.Interop;

[CRepr]
struct WINDOWCOMPOSITIONATTRIBDATA
{
	public WINDOWCOMPOSITIONATTRIB Attrib;
	public void* pvData;
	public uint cbData;
}
