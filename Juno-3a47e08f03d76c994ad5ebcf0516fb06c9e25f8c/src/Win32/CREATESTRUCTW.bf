namespace Juno;

using System;
using System.Interop;

[CRepr]
struct CREATESTRUCTW
{
	public void* lpCreateParams;
	public HINSTANCE hInstance;
	public HMENU hMenu;
	public HWND hwndParent;
	public int32 cy;
	public int32 cx;
	public int32 y;
	public int32 x;
	public LONG style;
	public LPCWSTR lpszName;
	public LPCWSTR lpszClass;
	public DWORD dwExStyle;
}
