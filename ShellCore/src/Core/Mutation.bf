namespace Shell.Core;

using System;

// A deferred structural change. Mutations refer to objects by Handle and re-validate them when applied,
// because the target may have been destroyed between queuing and applying.
abstract class Mutation
{
	public abstract void Apply(RuntimeContext context);
}
