namespace Shell.Core;

using System;

// Counts active traversals of a tree (rendering, input routing, update). While a traversal is active, code that
// wants to change the tree must defer the change through MutationQueue.
class TraversalGuard
{
	int mDepth;

	public bool mIsTraversing => mDepth > 0;

	public void Enter()
	{
		mDepth++;
	}

	public void Exit()
	{
		Runtime.Assert(mDepth > 0, "TraversalGuard.Exit without Enter");
		mDepth--;
	}
}
