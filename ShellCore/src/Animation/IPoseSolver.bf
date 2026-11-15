namespace Shell.Animation;

using System;
using Shell.Core;
using Shell.Styling;

// Extension point (not implemented yet): procedural posing, constraints and inverse kinematics.
// Order inside one frame: animation controllers (authored pose) -> Blueprint inputs -> pose solvers (procedural,
// operate on the animated pose) -> final property resolution. Solvers contribute in PropertyLayer.Solver, the topmost
// layer, so IK/constraints always have the last word over the bones/properties they declare they affect.
interface IPoseSolver
{
	StableId GetId();
	int GetOrder();
	void Solve(FrameContext frame, ISkeletonProvider skeleton, IContributionSink sink);
}
