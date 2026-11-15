namespace Shell.Animation;

using System;
using Shell.Core;

// Extension point (not implemented yet): supplies a skeleton - bones, a rest pose and a current pose - for rigged
// geometry. A future Mesh element binds weighted vertices to bones of a provider.
interface ISkeletonProvider
{
	StableId GetSkeletonId();
	int GetBoneCount();
	// Writes the local transform (x, y, rotation, scaleX, scaleY) of a bone into the output array.
	void GetBonePose(int bone, float[5] output);
}
