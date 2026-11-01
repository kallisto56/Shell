namespace Shell.Platform;

using System;
using System.Collections;
using Shell.Core;

// Capabilities granted to each package (by package id). Absent package = nothing granted.
class PermissionSet
{
	Dictionary<StableId, Capability> mGranted = new .() ~ delete _;

	public Capability GetGranted(StableId package)
	{
		if (mGranted.TryGetValue(package, let value))
			return value;
		return .None;
	}

	public void Grant(StableId package, Capability capabilities)
	{
		mGranted[package] = GetGranted(package) | capabilities;
	}

	public void Revoke(StableId package, Capability capabilities)
	{
		mGranted[package] = (Capability)((uint32)GetGranted(package) & ~(uint32)capabilities);
	}

	public bool IsGranted(StableId package, Capability required)
	{
		return ((uint32)GetGranted(package) & (uint32)required) == (uint32)required;
	}
}
