namespace Juno;

using System;
using System.Collections;

static class Icons
{
	// Loads an .ico file. width/height 0 = default system icon size. Free with Destroy.
	static public HICON LoadFromFile(StringView path, int32 width = 0, int32 height = 0)
	{
		let wide = scope List<char16>();
		Wide.Encode(path, wide);

		LOAD_IMAGE_FLAGS flags = .LR_LOADFROMFILE;
		if (width == 0 && height == 0)
			flags |= .LR_DEFAULTSIZE;
		return NativeMethods.LoadImageW(null, wide.Ptr, .IMAGE_ICON, width, height, flags);
	}

	// Extracts the icon with the given index from any exe/dll/ico. Both sizes are returned, free each with Destroy.
	static public bool ExtractFromFile(StringView path, int32 index, out HICON large, out HICON small)
	{
		large = null;
		small = null;

		let wide = scope List<char16>();
		Wide.Encode(path, wide);
		return NativeMethods.ExtractIconExW(wide.Ptr, index, &large, &small, 1) > 0;
	}

	// Extracts the icon that is packed into the running executable (Beef embeds the project icon as the first icon resource).
	static public bool ExtractFromExecutable(out HICON large, out HICON small, int32 index = 0)
	{
		large = null;
		small = null;

		char16[1024] path = default;
		DWORD length = NativeMethods.GetModuleFileNameW(null, &path[0], 1024);
		if (length == 0 || length >= 1024)
			return false;
		return NativeMethods.ExtractIconExW(&path[0], index, &large, &small, 1) > 0;
	}

	// Sets the big (taskbar / Alt+Tab) and small (title bar) icons of a window. The window does not take ownership.
	static public void SetWindowIcon(HWND hWnd, HICON big, HICON small)
	{
		if (big != null)
			NativeMethods.SendMessageW(hWnd, (UINT)WM_MESSAGE.WM_SETICON, (WPARAM)(uint)ICON_SIZE.ICON_BIG, (LPARAM)(int)big);
		if (small != null)
			NativeMethods.SendMessageW(hWnd, (UINT)WM_MESSAGE.WM_SETICON, (WPARAM)(uint)ICON_SIZE.ICON_SMALL, (LPARAM)(int)small);
	}

	static public void Destroy(HICON icon)
	{
		if (icon != null)
			NativeMethods.DestroyIcon(icon);
	}
}
