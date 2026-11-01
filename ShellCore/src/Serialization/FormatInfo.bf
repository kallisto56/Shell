namespace Shell.Serialization;

using System;
using Shell.Core;

static class FormatInfo
{
	public const String cMagic = "juno-shell";
	static public SchemaVersion sCurrent = SchemaVersion(1, 0);
	public const String cFileExtension = ".shell";
}
