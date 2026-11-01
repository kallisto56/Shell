namespace Shell.Core;

using System;

// Small typed variant. A plain struct (no ownership): text is interned in a StringPool.
// Formatting and comparison never depend on the current locale.
struct Value
{
	public ValueKind mKind;
	public int64 mInt;              // Bool, Int, Id, Handle (packed)
	public double mFloat;           // Float
	public float mX;                // Vector2.x, Color.r, Rect.x
	public float mY;
	public float mZ;                // Color.b, Rect.width
	public float mW;                // Color.a, Rect.height
	public StringView mString;      // String, Enum (case name)

	static public Value sNone = default;

	static public Value FromBool(bool value) { Value r = default; r.mKind = .Bool; r.mInt = value ? 1 : 0; return r; }
	static public Value FromInt(int64 value) { Value r = default; r.mKind = .Int; r.mInt = value; return r; }
	static public Value FromFloat(double value) { Value r = default; r.mKind = .Float; r.mFloat = value; return r; }
	static public Value FromString(StringView interned) { Value r = default; r.mKind = .String; r.mString = interned; return r; }
	static public Value FromEnum(StringView interned) { Value r = default; r.mKind = .Enum; r.mString = interned; return r; }
	static public Value FromVector2(float x, float y) { Value r = default; r.mKind = .Vector2; r.mX = x; r.mY = y; return r; }
	static public Value FromColor(float r, float g, float b, float a) { Value v = default; v.mKind = .Color; v.mX = r; v.mY = g; v.mZ = b; v.mW = a; return v; }
	static public Value FromRect(float x, float y, float w, float h) { Value r = default; r.mKind = .Rect; r.mX = x; r.mY = y; r.mZ = w; r.mW = h; return r; }
	static public Value FromId(StableId id) { Value r = default; r.mKind = .Id; r.mInt = (int64)id.mValue; return r; }
	static public Value FromHandle(Handle handle) { Value r = default; r.mKind = .Handle; r.mInt = handle.Pack(); return r; }

	public bool mIsNone => mKind == .None;

	public bool AsBool(bool fallback = false) => (mKind == .Bool) ? (mInt != 0) : fallback;
	public int64 AsInt(int64 fallback = 0) => (mKind == .Int) ? mInt : ((mKind == .Float) ? (int64)mFloat : fallback);
	public double AsFloat(double fallback = 0) => (mKind == .Float) ? mFloat : ((mKind == .Int) ? (double)mInt : fallback);
	public StringView AsString() => (mKind == .String || mKind == .Enum) ? mString : default;
	public StableId AsId() => (mKind == .Id) ? StableId((uint64)mInt) : StableId.sNone;
	public Handle AsHandle() => (mKind == .Handle) ? Handle.Unpack(mInt) : Handle.sNone;

	// Exact comparison. NaN equals NaN so that change detection does not fire every frame.
	public bool Equals(Value other)
	{
		if (mKind != other.mKind)
			return false;

		switch (mKind)
		{
		case .None:
			return true;
		case .Bool, .Int, .Id, .Handle:
			return mInt == other.mInt;
		case .Float:
			return mFloat == other.mFloat || (mFloat != mFloat && other.mFloat != other.mFloat);
		case .String, .Enum:
			return mString == other.mString;
		case .Vector2:
			return mX == other.mX && mY == other.mY;
		case .Color, .Rect:
			return mX == other.mX && mY == other.mY && mZ == other.mZ && mW == other.mW;
		}
	}

	// Diagnostic / debug text. (The saved format has its own writer.)
	public void ToString(String outString)
	{
		switch (mKind)
		{
		case .None: outString.Append("none");
		case .Bool: outString.Append((mInt != 0) ? "true" : "false");
		case .Int: mInt.ToString(outString);
		case .Float: mFloat.ToString(outString);
		case .String: outString.Append('"'); outString.Append(mString); outString.Append('"');
		case .Enum: outString.Append(mString);
		case .Vector2: outString.AppendF("({}, {})", mX, mY);
		case .Color: outString.AppendF("rgba({}, {}, {}, {})", mX, mY, mZ, mW);
		case .Rect: outString.AppendF("rect({}, {}, {}, {})", mX, mY, mZ, mW);
		case .Id: AsId().ToString(outString);
		case .Handle: outString.AppendF("handle#{}", mInt);
		}
	}
}
