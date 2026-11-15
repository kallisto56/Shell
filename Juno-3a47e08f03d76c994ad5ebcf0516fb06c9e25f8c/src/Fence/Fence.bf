namespace Juno;


using System;
using System.Diagnostics;
using System.Interop;


[CRepr]
struct Fence
{
	public ComPtr<ID3D11Query> mQuery;
}
