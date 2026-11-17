namespace Shell.Styling;

using System;
using Shell.Core;

struct Contribution
{
	public PropertyLayer mLayer;
	public ContributionBlend mBlend;
	public Value mValue;
	public float mWeight;       // 0..1 (blend trees and cross-fades)
	public int mSource;       // writer id (0 = authored value; style system, animation controllers ... use their own)
	public int mOrder;          // writer order inside a layer (controller order); ties keep insertion order
}
