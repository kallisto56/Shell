namespace Shell.Reflection;

using System;

struct SubscriptionId
{
	public uint32 mValue;

	public bool mIsValid => mValue != 0;
}
