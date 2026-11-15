namespace Juno;


using System;
using System.Diagnostics;
using System.Interop;


[CRepr]
struct RasterizerState
{
	public ComPtr<ID3D11RasterizerState> mState;
}
