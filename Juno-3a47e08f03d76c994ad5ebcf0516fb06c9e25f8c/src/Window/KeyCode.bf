namespace Juno;

using System;

// Windows virtual-key codes (same numeric values as the Beef IDE's KeyCode, extended with
// letters, digits, F13-F24 and a few punctuation keys). Aliases are allowed.
[AllowDuplicates]
enum KeyCode : int32
{
	case None = 0;

	case Backspace = 0x08;
	case Tab = 0x09;
	case Clear = 0x0C;
	case Enter = 0x0D;
	case Return = 0x0D;
	case Shift = 0x10;
	case Control = 0x11;
	case Alt = 0x12;
	case Pause = 0x13;
	case CapsLock = 0x14;
	case Escape = 0x1B;
	case Space = 0x20;
	case PageUp = 0x21;
	case PageDown = 0x22;
	case End = 0x23;
	case Home = 0x24;
	case Left = 0x25;
	case Up = 0x26;
	case Right = 0x27;
	case Down = 0x28;
	case PrintScreen = 0x2C;
	case Insert = 0x2D;
	case Delete = 0x2E;

	case Alpha0 = 0x30;
	case Alpha1 = 0x31;
	case Alpha2 = 0x32;
	case Alpha3 = 0x33;
	case Alpha4 = 0x34;
	case Alpha5 = 0x35;
	case Alpha6 = 0x36;
	case Alpha7 = 0x37;
	case Alpha8 = 0x38;
	case Alpha9 = 0x39;

	case A = 0x41;
	case B = 0x42;
	case C = 0x43;
	case D = 0x44;
	case E = 0x45;
	case F = 0x46;
	case G = 0x47;
	case H = 0x48;
	case I = 0x49;
	case J = 0x4A;
	case K = 0x4B;
	case L = 0x4C;
	case M = 0x4D;
	case N = 0x4E;
	case O = 0x4F;
	case P = 0x50;
	case Q = 0x51;
	case R = 0x52;
	case S = 0x53;
	case T = 0x54;
	case U = 0x55;
	case V = 0x56;
	case W = 0x57;
	case X = 0x58;
	case Y = 0x59;
	case Z = 0x5A;

	case LWin = 0x5B;
	case RWin = 0x5C;
	case Apps = 0x5D;

	case Numpad0 = 0x60;
	case Numpad1 = 0x61;
	case Numpad2 = 0x62;
	case Numpad3 = 0x63;
	case Numpad4 = 0x64;
	case Numpad5 = 0x65;
	case Numpad6 = 0x66;
	case Numpad7 = 0x67;
	case Numpad8 = 0x68;
	case Numpad9 = 0x69;
	case NumpadMultiply = 0x6A;
	case NumpadAdd = 0x6B;
	case NumpadSubtract = 0x6D;
	case NumpadDecimal = 0x6E;
	case NumpadDivide = 0x6F;

	case F1 = 0x70;
	case F2 = 0x71;
	case F3 = 0x72;
	case F4 = 0x73;
	case F5 = 0x74;
	case F6 = 0x75;
	case F7 = 0x76;
	case F8 = 0x77;
	case F9 = 0x78;
	case F10 = 0x79;
	case F11 = 0x7A;
	case F12 = 0x7B;
	case F13 = 0x7C;
	case F14 = 0x7D;
	case F15 = 0x7E;
	case F16 = 0x7F;
	case F17 = 0x80;
	case F18 = 0x81;
	case F19 = 0x82;
	case F20 = 0x83;
	case F21 = 0x84;
	case F22 = 0x85;
	case F23 = 0x86;
	case F24 = 0x87;

	case NumLock = 0x90;
	case ScrollLock = 0x91;

	case LShift = 0xA0;
	case RShift = 0xA1;
	case LControl = 0xA2;
	case RControl = 0xA3;
	case LAlt = 0xA4;
	case RAlt = 0xA5;

	case MediaNext = 0xB0;
	case MediaPrevious = 0xB1;
	case MediaStop = 0xB2;
	case MediaPlayPause = 0xB3;

	case Semicolon = 0xBA;
	case Plus = 0xBB;       // '=' / '+' key
	case Comma = 0xBC;
	case Minus = 0xBD;
	case Period = 0xBE;
	case Slash = 0xBF;
	case Grave = 0xC0;      // '`' / '~'
	case LeftBracket = 0xDB;
	case Backslash = 0xDC;
	case RightBracket = 0xDD;
	case Quote = 0xDE;

	case COUNT = 0x100;
}

extension KeyCode
{
	public bool mIsModifier
	{
		get
		{
			switch (this)
			{
			case .Shift, .LShift, .RShift, .Control, .LControl, .RControl, .Alt, .LAlt, .RAlt, .LWin, .RWin:
				return true;
			default:
				return false;
			}
		}
	}

	public bool mIsLetter => this >= .A && this <= .Z;
	public bool mIsDigit => (this >= .Alpha0 && this <= .Alpha9) || (this >= .Numpad0 && this <= .Numpad9);
	public bool mIsFunctionKey => this >= .F1 && this <= .F24;
	public bool mIsArrow => this >= .Left && this <= .Down;
}
