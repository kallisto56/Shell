namespace Shell.Render;

using System;
using System.Collections;
using Juno;
using Shell.Core;
using Shell.Elements;
using Shell.Rendering;
using Shell.Layout;

// Triangulates shapes and strokes into the batch renderer. Scratch lists are reused between calls (no per-frame allocation once warm).
//   Rounded rectangles / ellipses: convex fans for fills, a ring of quads for strokes (the stroke lies inside the box).
//   Paths: cached ear-clipping triangulation for closed contours, mitered quad strips for strokes.
class ShapePainter
{
	List<Vertex> mVertices = new .() ~ delete _;
	List<uint32> mIndices = new .() ~ delete _;
	List<PointF> mOuter = new .() ~ delete _;
	List<PointF> mInner = new .() ~ delete _;

	void Submit(Graphics g)
	{
		if (mIndices.Count > 0)
			g.DrawVertices(mVertices, mIndices);
		mVertices.Clear();
		mIndices.Clear();
	}

	void AddVertex(PointF p, Color color)
	{
		mVertices.Add(Vertex(p.mX, p.mY, 0, 0, 0, color));
	}

	// ---- outlines ----

	static int ArcSegments(float radius) => Math.Clamp((int)Math.Ceiling(radius * 0.5f), 4, 16);

	// Clockwise outline of a rounded rectangle inset by `inset` on every side. The vertex count depends only on `radius`, so an outer
	// and an inner outline (inset > 0) can be joined index by index.
	void BuildRoundedRect(List<PointF> points, float width, float height, float radius, float inset)
	{
		let segments = ArcSegments(radius);
		let r = Math.Max(Math.Min(radius, Math.Min(width, height) * 0.5f) - inset, 0);
		let left = inset;
		let top = inset;
		let right = width - inset;
		let bottom = height - inset;
		// corner centres: top-left, top-right, bottom-right, bottom-left; start angles 180, 270, 0, 90 degrees
		float[4] cx = .(left + r, right - r, right - r, left + r);
		float[4] cy = .(top + r, top + r, bottom - r, bottom - r);
		float[4] start = .(Math.PI_f, Math.PI_f * 1.5f, 0, Math.PI_f * 0.5f);
		for (int corner < 4)
		{
			for (int i = 0; i <= segments; i++)
			{
				let angle = start[corner] + (Math.PI_f * 0.5f) * (float)i / (float)segments;
				points.Add(PointF(cx[corner] + Math.Cos(angle) * r, cy[corner] + Math.Sin(angle) * r));
			}
		}
	}

	void BuildEllipse(List<PointF> points, float width, float height, float inset)
	{
		let n = Math.Clamp((int)Math.Ceiling(Math.Max(width, height) * 0.25f), 16, 128);
		let rx = Math.Max(width * 0.5f - inset, 0);
		let ry = Math.Max(height * 0.5f - inset, 0);
		for (int i < n)
		{
			let angle = Math.PI_f * 2.0f * (float)i / (float)n;
			points.Add(PointF(width * 0.5f + Math.Cos(angle) * rx, height * 0.5f + Math.Sin(angle) * ry));
		}
	}

	// ---- convex fill / ring ----

	void FillConvex(Graphics g, List<PointF> points, float centerX, float centerY, Color color)
	{
		AddVertex(PointF(centerX, centerY), color);
		for (let p in points)
			AddVertex(p, color);
		let n = points.Count;
		for (int i < n)
		{
			mIndices.Add(0);
			mIndices.Add((uint32)(1 + i));
			mIndices.Add((uint32)(1 + ((i + 1) % n)));
		}
		Submit(g);
	}

	void FillRing(Graphics g, List<PointF> outer, List<PointF> inner, Color color)
	{
		let n = outer.Count;
		for (int i < n)
			AddVertex(outer[i], color);
		for (int i < n)
			AddVertex(inner[i], color);
		for (int i < n)
		{
			let j = (i + 1) % n;
			let o0 = (uint32)i; let o1 = (uint32)j;
			let i0 = (uint32)(n + i); let i1 = (uint32)(n + j);
			mIndices.Add(o0); mIndices.Add(o1); mIndices.Add(i1);
			mIndices.Add(o0); mIndices.Add(i1); mIndices.Add(i0);
		}
		Submit(g);
	}

	// ---- shapes ----

	public void PaintShape(Graphics g, ShapeKind kind, float width, float height, float radius, float strokeWidth, Color fill, Color stroke)
	{
		if (width <= 0 || height <= 0)
			return;

		mOuter.Clear();
		if (kind == .Ellipse)
			BuildEllipse(mOuter, width, height, 0);
		else if (radius < 0.5f)
		{
			if (fill.mA > 0) g.FillRect(0, 0, width, height, fill);
			if (stroke.mA > 0 && strokeWidth > 0)
			{
				let t = Math.Min(strokeWidth, Math.Min(width, height) * 0.5f);
				g.FillRect(0, 0, width, t, stroke);
				g.FillRect(0, height - t, width, t, stroke);
				g.FillRect(0, t, t, height - 2 * t, stroke);
				g.FillRect(width - t, t, t, height - 2 * t, stroke);
			}
			return;
		}
		else
			BuildRoundedRect(mOuter, width, height, radius, 0);

		if (fill.mA > 0)
			FillConvex(g, mOuter, width * 0.5f, height * 0.5f, fill);

		if (stroke.mA > 0 && strokeWidth > 0)
		{
			mInner.Clear();
			if (kind == .Ellipse)
				BuildEllipse(mInner, width, height, strokeWidth);
			else
				BuildRoundedRect(mInner, width, height, radius, strokeWidth);
			FillRing(g, mOuter, mInner, stroke);
		}
	}

	// ---- paths ----

	// Closed contours are filled with their cached triangulation (simple polygons without holes).
	public void FillPath(Graphics g, PathGeometry geometry, Color color)
	{
		for (let contour in geometry.mContours)
		{
			let indices = contour.GetFillIndices();
			if (indices == null || indices.Count == 0)
				continue;
			for (let p in contour.mPoints)
				AddVertex(p, color);
			for (let index in indices)
				mIndices.Add((uint32)index);
			Submit(g);
		}
	}

	// Stroke centred on the polyline. Joins are mitered (limited to twice the half width).
	public void StrokePolyline(Graphics g, List<PointF> points, bool closed, float width, Color color)
	{
		let n = points.Count;
		if (n < 2 || width <= 0)
			return;
		let half = width * 0.5f;

		for (int i < n)
		{
			let prev = points[(i + n - 1) % n];
			let cur = points[i];
			let next = points[(i + 1) % n];
			let hasPrev = closed || i > 0;
			let hasNext = closed || i < n - 1;

			float n1x = 0; float n1y = 0; float n2x = 0; float n2y = 0;
			if (hasPrev) Normal(prev, cur, ref n1x, ref n1y);
			if (hasNext) Normal(cur, next, ref n2x, ref n2y);
			if (!hasPrev) { n1x = n2x; n1y = n2y; }
			if (!hasNext) { n2x = n1x; n2y = n1y; }

			var mx = n1x + n2x;
			var my = n1y + n2y;
			let dot = n1x * n2x + n1y * n2y;
			let scale = Math.Min(1.0f / Math.Max(1.0f + dot, 0.0001f), 2.0f) * half;
			mx *= scale;
			my *= scale;
			AddVertex(PointF(cur.mX + mx, cur.mY + my), color);
			AddVertex(PointF(cur.mX - mx, cur.mY - my), color);
		}

		let segments = closed ? n : n - 1;
		for (int i < segments)
		{
			let a = (uint32)(i * 2);
			let b = (uint32)(((i + 1) % n) * 2);
			mIndices.Add(a); mIndices.Add(a + 1); mIndices.Add(b);
			mIndices.Add(a + 1); mIndices.Add(b + 1); mIndices.Add(b);
		}
		Submit(g);
	}

	static void Normal(PointF a, PointF b, ref float nx, ref float ny)
	{
		let dx = b.mX - a.mX;
		let dy = b.mY - a.mY;
		let length = Math.Sqrt(dx * dx + dy * dy);
		if (length < 0.00001f)
			return;
		nx = -dy / length;
		ny = dx / length;
	}
}
