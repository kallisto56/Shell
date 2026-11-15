namespace Shell.Elements;

using System;
using System.Collections;
using Shell.Core;

// Basic vector geometry: an SVG style path flattened to polylines.
//
// Commands (absolute upper case, relative lower case): M x y, L x y, H x, V y, Q cx cy x y, C c1x c1y c2x c2y x y, Z.
// Numbers are separated by spaces or commas and use '.' as the decimal separator; any other command is an error.
// Curves are flattened into 16 segments. Closed contours can be filled (Triangulate: ear clipping, simple polygons without holes);
// every contour can be stroked.
class PathGeometry
{
	public List<PathContour> mContours = new .() ~ DeleteContainerAndItems!(_);
	public RectF mBounds;

	const int cCurveSegments = 16;

	static bool IsSeparator(char8 c) => c == ' ' || c == ',' || c == '\t' || c == '\n' || c == '\r';
	static bool IsDigit(char8 c) => c >= '0' && c <= '9';

	static void SkipSeparators(StringView s, ref int i)
	{
		while (i < s.Length && IsSeparator(s[i]))
			i++;
	}

	static Result<float> ReadNumber(StringView s, ref int i)
	{
		SkipSeparators(s, ref i);
		let start = i;
		if (i < s.Length && (s[i] == '-' || s[i] == '+'))
			i++;
		while (i < s.Length && IsDigit(s[i]))
			i++;
		if (i < s.Length && s[i] == '.')
		{
			i++;
			while (i < s.Length && IsDigit(s[i]))
				i++;
		}
		if (i < s.Length && (s[i] == 'e' || s[i] == 'E'))
		{
			i++;
			if (i < s.Length && (s[i] == '-' || s[i] == '+'))
				i++;
			while (i < s.Length && IsDigit(s[i]))
				i++;
		}
		if (i == start)
			return .Err;
		return float.Parse(s.Substring(start, i - start));
	}

	static public Result<PathGeometry> Parse(StringView data)
	{
		let geometry = new PathGeometry();
		if (!geometry.ParseInto(data))
		{
			delete geometry;
			return .Err;
		}
		return .Ok(geometry);
	}

	static bool ReadPair(StringView s, ref int i, float baseX, float baseY, bool relative, ref float x, ref float y)
	{
		if (!(ReadNumber(s, ref i) case .Ok(let a)))
			return false;
		if (!(ReadNumber(s, ref i) case .Ok(let b)))
			return false;
		x = relative ? baseX + a : a;
		y = relative ? baseY + b : b;
		return true;
	}

	bool ParseInto(StringView s)
	{
		var i = 0;
		var command = '\0';
		float cx = 0; float cy = 0;         // current point
		float sx = 0; float sy = 0;         // start of the current contour
		PathContour current = null;

		while (true)
		{
			SkipSeparators(s, ref i);
			if (i >= s.Length)
				break;

			let c = s[i];
			if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'))
			{
				command = c;
				i++;
				if (c == 'Z' || c == 'z')
				{
					if (current != null)
					{
						current.bClosed = true;
						cx = sx;
						cy = sy;
						current = null;
					}
					continue;
				}
			}
			else if (command == '\0')
			{
				return false;
			}

			switch (command)
			{
			case 'M', 'm':
			{
				float x = 0; float y = 0;
				if (!ReadPair(s, ref i, cx, cy, command == 'm', ref x, ref y)) return false;
				current = new PathContour();
				mContours.Add(current);
				current.mPoints.Add(PointF(x, y));
				cx = x; cy = y; sx = x; sy = y;
				command = (command == 'm') ? 'l' : 'L';     // further pairs are implicit line-tos
			}
			case 'L', 'l':
			{
				float x = 0; float y = 0;
				if (!ReadPair(s, ref i, cx, cy, command == 'l', ref x, ref y)) return false;
				current = EnsureContour(current, cx, cy, ref sx, ref sy);
				current.mPoints.Add(PointF(x, y));
				cx = x; cy = y;
			}
			case 'H', 'h':
			{
				if (!(ReadNumber(s, ref i) case .Ok(let value))) return false;
				current = EnsureContour(current, cx, cy, ref sx, ref sy);
				cx = (command == 'h') ? cx + value : value;
				current.mPoints.Add(PointF(cx, cy));
			}
			case 'V', 'v':
			{
				if (!(ReadNumber(s, ref i) case .Ok(let value))) return false;
				current = EnsureContour(current, cx, cy, ref sx, ref sy);
				cy = (command == 'v') ? cy + value : value;
				current.mPoints.Add(PointF(cx, cy));
			}
			case 'Q', 'q':
			{
				float x1 = 0; float y1 = 0; float x = 0; float y = 0;
				let rel = (command == 'q');
				if (!ReadPair(s, ref i, cx, cy, rel, ref x1, ref y1)) return false;
				if (!ReadPair(s, ref i, cx, cy, rel, ref x, ref y)) return false;
				current = EnsureContour(current, cx, cy, ref sx, ref sy);
				for (int step = 1; step <= cCurveSegments; step++)
				{
					let t = (float)step / (float)cCurveSegments;
					let u = 1 - t;
					current.mPoints.Add(PointF(u * u * cx + 2 * u * t * x1 + t * t * x, u * u * cy + 2 * u * t * y1 + t * t * y));
				}
				cx = x; cy = y;
			}
			case 'C', 'c':
			{
				float x1 = 0; float y1 = 0; float x2 = 0; float y2 = 0; float x = 0; float y = 0;
				let rel = (command == 'c');
				if (!ReadPair(s, ref i, cx, cy, rel, ref x1, ref y1)) return false;
				if (!ReadPair(s, ref i, cx, cy, rel, ref x2, ref y2)) return false;
				if (!ReadPair(s, ref i, cx, cy, rel, ref x, ref y)) return false;
				current = EnsureContour(current, cx, cy, ref sx, ref sy);
				for (int step = 1; step <= cCurveSegments; step++)
				{
					let t = (float)step / (float)cCurveSegments;
					let u = 1 - t;
					let b0 = u * u * u;
					let b1 = 3 * u * u * t;
					let b2 = 3 * u * t * t;
					let b3 = t * t * t;
					current.mPoints.Add(PointF(b0 * cx + b1 * x1 + b2 * x2 + b3 * x, b0 * cy + b1 * y1 + b2 * y2 + b3 * y));
				}
				cx = x; cy = y;
			}
			default:
				return false;
			}
		}

		ComputeBounds();
		return true;
	}

	PathContour EnsureContour(PathContour current, float x, float y, ref float startX, ref float startY)
	{
		if (current != null)
			return current;
		let contour = new PathContour();
		mContours.Add(contour);
		contour.mPoints.Add(PointF(x, y));
		startX = x;
		startY = y;
		return contour;
	}

	void ComputeBounds()
	{
		float minX = float.MaxValue; float minY = float.MaxValue; float maxX = -float.MaxValue; float maxY = -float.MaxValue;
		bool any = false;
		for (let contour in mContours)
		{
			for (let point in contour.mPoints)
			{
				any = true;
				minX = Math.Min(minX, point.mX); maxX = Math.Max(maxX, point.mX);
				minY = Math.Min(minY, point.mY); maxY = Math.Max(maxY, point.mY);
			}
		}
		mBounds = any ? RectF(minX, minY, maxX - minX, maxY - minY) : RectF(0, 0, 0, 0);
	}

	// Ear clipping triangulation of a simple polygon. Appends triples of indices into `polygon`. A trailing point equal to the first
	// one is ignored. Degenerate input falls back to a triangle fan.
	static public void Triangulate(List<PointF> polygon, List<int32> indices)
	{
		var count = polygon.Count;
		if (count > 1 && polygon[0].mX == polygon[count - 1].mX && polygon[0].mY == polygon[count - 1].mY)
			count--;
		if (count < 3)
			return;

		float area = 0;
		for (int i < count)
		{
			let a = polygon[i];
			let b = polygon[(i + 1) % count];
			area += a.mX * b.mY - b.mX * a.mY;
		}
		let orientation = (area >= 0) ? 1.0f : -1.0f;

		let remaining = scope List<int32>();
		for (int i < count)
			remaining.Add((int32)i);

		var guard = count * count + 8;
		while (remaining.Count > 3 && guard-- > 0)
		{
			bool bClipped = false;
			for (int i < remaining.Count)
			{
				let ia = remaining[(i + remaining.Count - 1) % remaining.Count];
				let ib = remaining[i];
				let ic = remaining[(i + 1) % remaining.Count];
				let a = polygon[ia]; let b = polygon[ib]; let c = polygon[ic];

				let cross = (b.mX - a.mX) * (c.mY - b.mY) - (b.mY - a.mY) * (c.mX - b.mX);
				if (cross * orientation <= 0)
					continue;       // reflex or collinear corner

				bool bInside = false;
				for (let other in remaining)
				{
					if (other == ia || other == ib || other == ic)
						continue;
					if (PointInTriangle(polygon[other], a, b, c))
					{
						bInside = true;
						break;
					}
				}
				if (bInside)
					continue;

				indices.Add(ia); indices.Add(ib); indices.Add(ic);
				remaining.RemoveAt(i);
				bClipped = true;
				break;
			}
			if (!bClipped)
				break;      // self-intersecting or degenerate: use the fan below for what is left
		}

		if (remaining.Count == 3)
		{
			indices.Add(remaining[0]); indices.Add(remaining[1]); indices.Add(remaining[2]);
		}
		else if (remaining.Count > 3)
		{
			for (int i = 1; i < remaining.Count - 1; i++)
			{
				indices.Add(remaining[0]); indices.Add(remaining[i]); indices.Add(remaining[i + 1]);
			}
		}
	}

	static bool PointInTriangle(PointF p, PointF a, PointF b, PointF c)
	{
		let d1 = (p.mX - b.mX) * (a.mY - b.mY) - (a.mX - b.mX) * (p.mY - b.mY);
		let d2 = (p.mX - c.mX) * (b.mY - c.mY) - (b.mX - c.mX) * (p.mY - c.mY);
		let d3 = (p.mX - a.mX) * (c.mY - a.mY) - (c.mX - a.mX) * (p.mY - a.mY);
		let bNegative = (d1 < 0) || (d2 < 0) || (d3 < 0);
		let bPositive = (d1 > 0) || (d2 > 0) || (d3 > 0);
		return !(bNegative && bPositive);
	}
}
