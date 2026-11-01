namespace Shell.Animation;

using System;
using Shell.Core;
using Shell.Styling;

// Where animation, Blueprint and solver systems deliver property values. Nothing writes to a property directly:
// contributions are collected per (target, property) and resolved by ContributionStack in the Bindings phase.
interface IContributionSink
{
	void Contribute(StableId target, StringView property, Contribution contribution);
}
