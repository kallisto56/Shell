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

	// Removes the contributions of one writer in one layer. `order` < 0 matches every order of that writer.
	public bool RemoveLayerSource(PropertyLayer layer, int source, int order = -1)
	{
		return mItems.RemoveAll(scope (c) => c.mLayer == layer && c.mSource == source && (order < 0 || c.mOrder == order)) > 0;
	}

	// Removes everything one writer contributed, in every layer.
	public bool RemoveSource(int source)
	{
		return mItems.RemoveAll(scope (c) => c.mSource == source) > 0;
	}

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
