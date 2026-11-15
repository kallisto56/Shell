namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Elements;
using Shell.Layout;
using Shell.Widgets;

// Layout phase: measures and arranges the element tree of every widget and refreshes the world state (matrix, clip, opacity) of the
// elements. Runs after bindings, so everything a binding changed this frame is laid out in the same frame.
//
// Work is proportional to what changed: a tree is laid out only when its root is dirty or the widget size changed, clean element
// subtrees return immediately, and world state is recomputed only for dirty subtrees (or everything when the widget moved).
class LayoutSystem : IRuntimeSystem
{
	RuntimeContext mContext;
	public LayoutEngine mEngine = new .() ~ delete _;
	public Handle mRoot;
	public int mOrder;

	// Statistics of the last frame.
	public int mMeasured;
	public int mArranged;
	public int mStateUpdates;
	public int mTreesLaidOut;

	public this(RuntimeContext context, ITextMeasurer text, IImageMeasurer images)
	{
		mContext = context;
		mEngine.mText = text;
		mEngine.mImages = images;
	}

	public void SetRoot(Widget root)
	{
		mRoot = root.mHandle;
	}

	public UpdatePhase GetPhase() => .Layout;
	public int GetOrder() => mOrder;

	public void Update(FrameContext frame)
	{
		mMeasured = 0;
		mArranged = 0;
		mStateUpdates = 0;
		mTreesLaidOut = 0;
		let root = mContext.Resolve<Widget>(mRoot);
		if (root != null)
			Visit(root);
	}

	void Visit(Widget widget)
	{
		if (!widget.mIsAlive || !widget.mProperties.Get(WidgetTypes.sVisible).AsBool(true))
			return;

		let tree = widget.mElements;
		if (tree != null && tree.mRoot != null)
		{
			let bounds = widget.mBounds;
			let origin = widget.GetRootPosition();
			let root = tree.mRoot;

			if (root.bMeasureDirty || root.bArrangeDirty || tree.mLayoutWidth != bounds.mWidth || tree.mLayoutHeight != bounds.mHeight)
			{
				mEngine.LayoutTree(tree, bounds.mWidth, bounds.mHeight);
				mMeasured += mEngine.mMeasuredNodes;
				mArranged += mEngine.mArrangedNodes;
				mTreesLaidOut++;
			}

			let bMoved = (tree.mOriginX != origin.mX || tree.mOriginY != origin.mY);
			tree.mOriginX = origin.mX;
			tree.mOriginY = origin.mY;
			mStateUpdates += ElementStateUpdater.Update(tree, origin.mX, origin.mY, bMoved);
		}

		for (let child in widget.mChildren)
			Visit(child);
	}
}
