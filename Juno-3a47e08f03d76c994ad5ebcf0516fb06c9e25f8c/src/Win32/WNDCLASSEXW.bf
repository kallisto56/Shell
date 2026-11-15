namespace Juno;

using System;
using System.Interop;

[CRepr]
struct WNDCLASSEXW
{
	public UINT cbSize;
	public UINT style;
	public WNDPROC lpfnWndProc;
	public int32 cbClsExtra;
	public int32 cbWndExtra;
	public HINSTANCE hInstance;
	public HICON hIcon;
	public HCURSOR hCursor;
	public HBRUSH hbrBackground;
	public LPCWSTR lpszMenuName;
	public LPCWSTR lpszClassName;
	public HICON hIconSm;
}
