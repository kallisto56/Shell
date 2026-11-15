namespace Shell.Serialization;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

// Header of a saved project / package: identity, format version, dependencies and the capabilities it asks for.
// Requested capabilities are requests only; nothing is granted until the user approves them (PermissionSet).
class PackageManifest
{
	public StableId mId;
	public String mName = new .() ~ delete _;
	public SchemaVersion mFormat;
	public Capability mRequested;
	public List<StableId> mDependencies = new .() ~ delete _;   // other packages (shared themes, UserWidget libraries)
}
