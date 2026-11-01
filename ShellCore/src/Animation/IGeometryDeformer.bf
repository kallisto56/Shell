namespace Shell.Animation;

using System;
using Shell.Core;

// Extension point (not implemented yet): deforms vector geometry or meshes after the pose is final
// (weighted skinning, free-form deformation, shader-driven deformation).
interface IGeometryDeformer
{
	StableId GetId();
	bool CanDeform(StableId element);
}
