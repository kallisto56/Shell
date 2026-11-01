namespace Shell.PlatformWin;

using System;

static class WinMessages
{
	public const uint32 cKillFocus = 0x0008;
	public const uint32 cSetCursor = 0x0020;
	public const uint32 cKeyDown = 0x0100;
	public const uint32 cKeyUp = 0x0101;
	public const uint32 cChar = 0x0102;
	public const uint32 cSysKeyDown = 0x0104;
	public const uint32 cSysKeyUp = 0x0105;
	public const uint32 cSysCommand = 0x0112;
	public const uint32 cMouseMove = 0x0200;
	public const uint32 cLButtonDown = 0x0201;
	public const uint32 cLButtonUp = 0x0202;
	public const uint32 cRButtonDown = 0x0204;
	public const uint32 cRButtonUp = 0x0205;
	public const uint32 cMButtonDown = 0x0207;
	public const uint32 cMButtonUp = 0x0208;
	public const uint32 cMouseWheel = 0x020A;
	public const uint32 cXButtonDown = 0x020B;
	public const uint32 cXButtonUp = 0x020C;
	public const uint32 cMouseHWheel = 0x020E;
	public const uint32 cCaptureChanged = 0x0215;
	public const uint32 cImeStartComposition = 0x010D;
	public const uint32 cImeEndComposition = 0x010E;
	public const uint32 cImeComposition = 0x010F;
	public const uint32 cImeSetContext = 0x0281;
}
