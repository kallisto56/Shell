namespace Juno;

using System;
using System.Interop;

// Opaque handle. Only ever used through pointers (BlendState*).
[CRepr]
struct BlendState
{
}
