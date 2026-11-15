namespace Shell.Format;

using System;

// Enums are saved by case name, so reordering or inserting cases never changes the meaning of existing files.
// Flag enums are saved as integers instead (see NodeWriter.Flags / NodeReader.Flags).
static class EnumCodec
{
	static public void Name<T>(T value, String output) where T : enum
	{
		value.ToString(output);
	}

	static public Result<T> Parse<T>(StringView text) where T : enum
	{
		return Enum.Parse<T>(text);
	}
}
