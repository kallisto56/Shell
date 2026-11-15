namespace Juno;

using System;
using System.Interop;

[CRepr]
struct MSG
{
	public HWND hwnd;
	public UINT message;
	public WPARAM wParam;
	public LPARAM lParam;
	public DWORD time;
	public POINT pt;
	public DWORD lPrivate;
}
