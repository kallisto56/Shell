namespace Shell.Styling;

using System;
using System.Collections;
using Shell.Core;

// All contributions to one (object, property) in the current frame. Resolve() applies them from the lowest layer to the
// highest; inside a layer by order, then insertion. Deterministic: the result never depends on which system ran first.
class ContributionStack
{
	List<Contribution> mItems = new .() ~ delete _;

	public int mCount => mItems.Count;

	public void Clear()
	{
		mItems.Clear();
	}

	public void Add(Contribution contribution)
	{
		mItems.Add(contribution);
	}

	// Removes everything a layer contributed (for example Blueprint overrides being released).
	public void RemoveLayer(PropertyLayer layer)
	{
		mItems.RemoveAll(scope (c) => c.mLayer == layer);
	}

	public Value Resolve(Value defaultValue)
	{
		let sorted = scope List<(Contribution c, int index)>();
		for (int i < mItems.Count)
			sorted.Add((mItems[i], i));
		sorted.Sort(scope (a, b) =>
		{
			if (a.c.mLayer != b.c.mLayer) return (int)a.c.mLayer <=> (int)b.c.mLayer;
			if (a.c.mOrder != b.c.mOrder) return a.c.mOrder <=> b.c.mOrder;
			return a.index <=> b.index;
		});

		var result = defaultValue;
		for (let entry in sorted)
		{
			let c = entry.c;
			switch (c.mBlend)
			{
			case .Replace:  result = ValueMath.Lerp(result, c.mValue, c.mWeight);
			case .Add:      result = ValueMath.AddScaled(result, c.mValue, c.mWeight);
			case .Multiply: result = ValueMath.MultiplyBy(result, c.mValue, c.mWeight);
			}
		}
		return result;
	}
}
