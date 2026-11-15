namespace Shell.Layout;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Reflection;
using Juno;

// Computes the world state of arranged elements: matrix (root space = window client coordinates), clip, effective opacity and the
// axis-aligned world bounds. Runs after layout; only dirty subtrees are recomputed.
//
// Inheritance follows the layout hierarchy (an element lives in its layout parent's coordinate space):
//   world   = local * parent world, local = pivot based scale and rotation, then translation by (arranged origin + Position)
//   clip    = parent clip intersected with the element's own box when ClipToBounds is set (axis-aligned approximation for rotation)
//   opacity = product of the opacities down the tree; an isolated group (CompositeMode != None) resets it to 1 for its content and
//             exposes the product as mCompositeOpacity, applied when the group surface is composited.
static class ElementStateUpdater
{
	static public int Update(ElementTree tree, float originX, float originY, bool force)
	{
		if (tree.mRoot == null)
			return 0;
		int count = 0;
		let world = Matrix3x2.CreateTranslation(Vector2(originX, originY));
		UpdateElement(tree, tree.mRoot, world, false, RectF(0, 0, 0, 0), 1.0f, force, ref count);
		return count;
	}

	static void UpdateElement(ElementTree tree, Element element, Matrix3x2 parentWorld, bool parentHasClip, RectF parentClip, float parentOpacity, bool forced, ref int count)
	{
		if (!element.mIsVisible)
			return;

		let recompute = forced || element.bStateDirty;
		if (!recompute && !element.bSubtreeStateDirty)
			return;

		if (recompute)
		{
			count++;
			let p = element.mProperties;
			let rect = element.mArranged;
			let position = p.Get(ElementTypes.sPosition);
			let scale = p.Get(ElementTypes.sScale);
			let pivot = p.Get(ElementTypes.sPivot);
			let rotation = (float)p.Get(ElementTypes.sRotation).AsFloat();

			let pivotPoint = Vector2(rect.mWidth * pivot.mX, rect.mHeight * pivot.mY);
			var local = Matrix3x2.CreateTranslation(Vector2(-pivotPoint.mX, -pivotPoint.mY));
			if (scale.mX != 1 || scale.mY != 1)
				local = local * Matrix3x2.CreateScale(Vector2(scale.mX, scale.mY));
			if (rotation != 0)
				local = local * Matrix3x2.CreateRotation(rotation, Vector2(0, 0));
			local = local * Matrix3x2.CreateTranslation(Vector2(pivotPoint.mX + rect.mX + position.mX, pivotPoint.mY + rect.mY + position.mY));

			element.mWorld = local * parentWorld;

			// World bounds: transform the four corners.
			let m = element.mWorld;
			float minX = float.MaxValue; float minY = float.MaxValue; float maxX = -float.MaxValue; float maxY = -float.MaxValue;
			for (int corner < 4)
			{
				let cx = ((corner & 1) != 0) ? rect.mWidth : 0.0f;
				let cy = ((corner & 2) != 0) ? rect.mHeight : 0.0f;
				let wx = cx * m.m11 + cy * m.m21 + m.m31;
				let wy = cx * m.m12 + cy * m.m22 + m.m32;
				minX = Math.Min(minX, wx); maxX = Math.Max(maxX, wx);
				minY = Math.Min(minY, wy); maxY = Math.Max(maxY, wy);
			}
			element.mWorldBounds = RectF(minX, minY, maxX - minX, maxY - minY);

			// Clip
			element.bHasClip = parentHasClip;
			element.mClip = parentClip;
			if (p.Get(ElementTypes.sClipToBounds).AsBool())
			{
				element.mClip = element.bHasClip ? parentClip.Intersection(element.mWorldBounds) : element.mWorldBounds;
				element.bHasClip = true;
			}

			// Opacity
			let opacity = Math.Clamp((float)p.Get(ElementTypes.sOpacity).AsFloat(), 0, 1);
			element.mCompositeOpacity = parentOpacity * opacity;
			element.mEffectiveOpacity = (element.mComposite != .None) ? 1.0f : element.mCompositeOpacity;
			element.bStateDirty = false;
		}
		element.bSubtreeStateDirty = false;

		let childOpacity = (element.mComposite != .None) ? 1.0f : element.mEffectiveOpacity;
		let children = scope List<Element>();
		tree.GetLayoutChildren(element, children);
		for (let child in children)
			UpdateElement(tree, child, element.mWorld, element.bHasClip, element.mClip, childOpacity, recompute, ref count);
	}
}
