namespace Shell.Elements;

using System;
using Shell.Core;

struct RenderItem
{
	public RenderItemKind mKind;
	public Handle mElement;
	public int mDepth;      // ownership depth (transform / clip stack is reconstructed from the element chain)
}
