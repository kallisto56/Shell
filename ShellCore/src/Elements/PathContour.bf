namespace Shell.Elements;

using System;
using System.Collections;
using Shell.Core;

class PathContour
{
	public List<PointF> mPoints = new .() ~ delete _;
	public bool bClosed;

	// Triangulation of a closed contour, computed on first use by the renderer and kept as long as the geometry lives.
	public List<int32> mFillIndices ~ delete _;
	public bool bTriangulated;

	public List<int32> GetFillIndices()
	{
		if (!bTriangulated)
		{
			bTriangulated = true;
			if (bClosed && mPoints.Count >= 3)
			{
				mFillIndices = new List<int32>();
				PathGeometry.Triangulate(mPoints, mFillIndices);
			}
		}
		return mFillIndices;
	}
}
