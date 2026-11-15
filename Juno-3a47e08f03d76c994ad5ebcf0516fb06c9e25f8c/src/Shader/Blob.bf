namespace Juno;

using System;
using System.Interop;

// Opaque handle. Only ever used through pointers (Blob*).
[CRepr]
struct Blob
{
}
