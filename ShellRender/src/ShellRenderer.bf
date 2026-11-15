namespace Shell.Render;

using System;
using System.Collections;
using Juno;
using Shell.Core;
using Shell.Elements;
using Shell.Rendering;
using Shell.Layout;
using Shell.Widgets;
using Shell.Reflection;

// Draws the widget tree: for each widget, its element layers with order <= 0 (underlay, main content), then its child widgets, then
// the layers with order > 0 (overlay). Everything lives in root space (window client coordinates): the layout system has already
// computed the world matrix, clip and opacity of every element, so drawing an element is "push clip, push transform, paint, pop".
//
// Isolated groups: the element and its same-layer descendants are drawn into a pooled render target (sized to the visible part of
// the element's bounds plus the padding its effects need), the effect passes run on that surface in list order, and the result is
// composited with the group opacity (premultiplied alpha). Nested groups work: each level has its own surface and origin.
// Backdrop groups: the part of the current target behind the element is copied out, the effects run on the copy, and the result is
// written back before the element draws its own content (blur-behind). When any element in the frame needs it the whole frame is
// rendered into an off-screen scene target first (one extra full-screen blit).
//
// Between two draws the Graphics transform / clip / tint stacks are empty: a group moves its origin instead (every draw subtracts the
// current surface origin), so surface and effect drawing always happens in plain target pixels.
class ShellRenderer
{
	struct GroupFrame
	{
		public Element mElement;
		public JunoSurface mSurface;        // isolated group surface (null when skipped / backdrop)
		public int mX;                      // surface origin in root space (device pixels)
		public int mY;
		public int mWidth;                  // size of the used region
		public int mHeight;
		public float mPreviousOriginX;
		public float mPreviousOriginY;
		public int mPreviousWidth;
		public int mPreviousHeight;
		public bool bSkipped;
		public bool bBackdrop;
	}

	public Graphics mGraphics;
	public RuntimeContext mContext;
	public DiagnosticSink mSink;
	public FontCatalog mFonts;
	public ImageCatalog mImages;
	public JunoSurfacePool mPool;
	public EffectPassRegistry mEffects = new .() ~ delete _;
	public RenderStats mStats;
	public JunoTextMeasurer mTextMeasurer ~ delete _;
	JunoEffectContext mEffectContext ~ delete _;
	ElementPainter mPainter ~ delete _;

	List<GroupFrame> mGroups = new .() ~ delete _;
	int mSkipDepth;
	float mOriginX;                         // origin of the current target in root space
	float mOriginY;
	int mTargetWidth;                       // size of the current target
	int mTargetHeight;
	HashSet<String> mReported = new .() ~ DeleteContainerAndItems!(_);

	public this(Graphics graphics, RuntimeContext context, DiagnosticSink sink)
	{
		mGraphics = graphics;
		mContext = context;
		mSink = sink;
		mFonts = new FontCatalog(graphics.mDevice, sink);
		mImages = new ImageCatalog(graphics.mDevice, sink);
		mPool = new JunoSurfacePool(graphics, sink);
		mTextMeasurer = new JunoTextMeasurer(mFonts);
		mEffectContext = new JunoEffectContext(graphics, mPool, sink);
		mPainter = new ElementPainter(mFonts, mImages);

		mEffects.Register(new BlurPass());
		mEffects.Register(new ShadowPass(.DropShadow));
		mEffects.Register(new ShadowPass(.Glow));
	}

	public ~this()
	{
		delete mFonts;
		delete mImages;
		delete mPool;
	}

	// Layout needs the same fonts and image sizes as drawing.
	public ITextMeasurer mText => mTextMeasurer;
	public IImageMeasurer mImageSizes => mImages;

	// ---- frame ----

	static bool NeedsScene(ShellWidget widget)
	{
		if (widget.mElements != null)
		{
			widget.mElements.EnsureRenderLists();
			if (widget.mElements.bHasBackdrop)
				return true;
		}
		for (let child in widget.mChildren)
		{
			if (NeedsScene(child))
				return true;
		}
		return false;
	}

	public void Render(ShellWidget root, double deltaSeconds)
	{
		mStats = default;
		mPainter.mDeltaSeconds = deltaSeconds;
		mPool.BeginFrame();
		mGroups.Clear();
		mSkipDepth = 0;
		mOriginX = 0;
		mOriginY = 0;
		mTargetWidth = mGraphics.mTargetWidth;
		mTargetHeight = mGraphics.mTargetHeight;

		JunoSurface scene = null;
		if (NeedsScene(root))
		{
			scene = mPool.Acquire(mTargetWidth, mTargetHeight) as JunoSurface;
			if (scene != null)
				mGraphics.PushRenderTarget(scene.mTarget);
		}
		mSceneTarget = (scene != null) ? scene.mTarget : null;

		RenderWidget(root);

		if (scene != null)
		{
			mGraphics.PopRenderTarget();
			mGraphics.SetBlendMode(.Premultiplied);
			mGraphics.DrawTexture(scene.mTarget.mColor, Rect(0, 0, (float)mTargetWidth, (float)mTargetHeight), Rect(0, 0, (float)mTargetWidth, (float)mTargetHeight), Color(255, 255, 255, 255));
			mGraphics.SetBlendMode(.Alpha);
			mPool.Release(scene);
			mSceneTarget = null;
		}
		mStats.mSurfacesInUse = mPool.mInUse;
		mPool.EndFrame();
	}

	void RenderWidget(ShellWidget widget)
	{
		if (!widget.mIsAlive || !widget.mProperties.Get(WidgetTypes.sVisible).AsBool(true))
			return;
		mStats.mWidgets++;

		let tree = widget.mElements;
		if (tree != null && tree.mRoot != null)
		{
			tree.EnsureRenderLists();
			Execute(tree.mRenderPre);
		}
		for (let child in widget.mChildren)
			RenderWidget(child);
		if (tree != null && tree.mRoot != null)
			Execute(tree.mRenderPost);
	}

	void Execute(List<RenderItem> items)
	{
		for (let item in items)
		{
			let element = mContext.Resolve<Element>(item.mElement);
			if (element == null || !element.mIsAlive)
				continue;
			switch (item.mKind)
			{
			case .Draw: if (mSkipDepth == 0) DrawElement(element);
			case .BeginGroup: BeginGroup(element);
			case .EndGroup: EndGroup(element);
			}
		}
	}

	// ---- elements ----

	bool IsOutside(RectF bounds)
	{
		return (bounds.mX - mOriginX > (float)mTargetWidth) || bounds.mY - mOriginY > (float)mTargetHeight
			|| bounds.mRight - mOriginX < 0 || bounds.mBottom - mOriginY < 0;
	}

	void DrawElement(Element element)
	{
		if (element.mKind == .Container)
			return;
		let opacity = element.mEffectiveOpacity;
		if (opacity <= 0.002f)
			return;
		if (IsOutside(element.mWorldBounds))
		{
			mStats.mElementsCulled++;
			return;
		}

		let g = mGraphics;
		if (element.bHasClip)
			g.PushClip(Rect(element.mClip.mX - mOriginX, element.mClip.mY - mOriginY, element.mClip.mWidth, element.mClip.mHeight));
		g.PushTransform(element.mWorld * Matrix3x2.CreateTranslation(Vector2(-mOriginX, -mOriginY)));
		if (opacity < 0.998f)
			g.PushTint(Color(1.0f, 1.0f, 1.0f, opacity));

		mPainter.Paint(g, element);
		mStats.mElementsDrawn++;

		if (opacity < 0.998f)
			g.PopTint();
		g.PopTransform();
		if (element.bHasClip)
			g.PopClip();
	}

	// ---- groups ----

	void ReportOnce(StringView code, StringView message)
	{
		let key = scope String(message);
		if (mReported.Contains(key))
			return;
		mReported.Add(new String(message));
		if (mSink != null)
			mSink.Warning(code, message);
	}

	// Sum of the paddings of the element's enabled effects (missing passes are reported once and ignored).
	float TotalPadding(Element element)
	{
		float padding = 0;
		for (let effect in element.mEffects)
		{
			if (!effect.bEnabled)
				continue;
			let pass = mEffects.Find(effect.mKind, effect.mCustomName);
			if (pass == null)
			{
				ReportOnce("REN0020", scope $"No effect pass is registered for '{effect.mKind}' {effect.mCustomName}.");
				continue;
			}
			padding += pass.GetPadding(effect);
		}
		return padding;
	}

	IRenderSurface RunEffects(Element element, IRenderSurface surface)
	{
		var current = surface;
		for (let effect in element.mEffects)
		{
			if (!effect.bEnabled)
				continue;
			let pass = mEffects.Find(effect.mKind, effect.mCustomName);
			if (pass == null)
				continue;
			let result = pass.Apply(mEffectContext, current, effect);
			mStats.mEffectPasses++;
			if (result != current)
			{
				mPool.Release(current);
				current = result;
			}
		}
		return current;
	}

	void BeginGroup(Element element)
	{
		GroupFrame frame = default;
		frame.mElement = element;
		frame.mPreviousOriginX = mOriginX;
		frame.mPreviousOriginY = mOriginY;
		frame.mPreviousWidth = mTargetWidth;
		frame.mPreviousHeight = mTargetHeight;

		if (mSkipDepth > 0 || element.mIsVisible == false)
		{
			frame.bSkipped = true;
			mSkipDepth++;
			mGroups.Add(frame);
			return;
		}

		let padding = TotalPadding(element);
		let wanted = element.mWorldBounds.Inflate(padding);
		// Only the part that can end up on the current target is rendered.
		let visible = Rect(mOriginX, mOriginY, (float)mTargetWidth, (float)mTargetHeight).Inflate(padding);
		let area = wanted.Intersection(visible);
		if (area.mWidth < 1 || area.mHeight < 1)
		{
			frame.bSkipped = true;
			mSkipDepth++;
			mGroups.Add(frame);
			return;
		}

		frame.mX = (int)Math.Floor(area.mX);
		frame.mY = (int)Math.Floor(area.mY);
		frame.mWidth = (int)Math.Ceiling(area.mRight) - frame.mX;
		frame.mHeight = (int)Math.Ceiling(area.mBottom) - frame.mY;
		mStats.mGroups++;

		if (element.mComposite == .BackdropGroup)
		{
			frame.bBackdrop = true;
			ApplyBackdrop(element, frame);
			mGroups.Add(frame);
			return;
		}

		frame.mSurface = mPool.Acquire(frame.mWidth, frame.mHeight) as JunoSurface;
		if (frame.mSurface == null)
		{
			frame.bSkipped = true;
			mSkipDepth++;
			mGroups.Add(frame);
			return;
		}
		mGraphics.PushRenderTarget(frame.mSurface.mTarget);
		mOriginX = (float)frame.mX;
		mOriginY = (float)frame.mY;
		mTargetWidth = frame.mSurface.mWidth;
		mTargetHeight = frame.mSurface.mHeight;
		mGroups.Add(frame);
	}

	void EndGroup(Element element)
	{
		if (mGroups.Count == 0)
			return;
		let frame = mGroups.PopBack();
		if (frame.bSkipped)
		{
			mSkipDepth--;
			return;
		}
		if (frame.bBackdrop)
			return;     // the backdrop was applied when the group began; the element's own content has been drawn since

		let g = mGraphics;
		g.PopRenderTarget();
		mOriginX = frame.mPreviousOriginX;
		mOriginY = frame.mPreviousOriginY;
		mTargetWidth = frame.mPreviousWidth;
		mTargetHeight = frame.mPreviousHeight;

		var result = RunEffects(element, frame.mSurface) as JunoSurface;
		if (result == null)
			result = frame.mSurface;

		let opacity = Math.Clamp(element.mCompositeOpacity, 0, 1);
		if (opacity > 0.002f)
		{
			if (element.bHasClip)
				g.PushClip(Rect(element.mClip.mX - mOriginX, element.mClip.mY - mOriginY, element.mClip.mWidth, element.mClip.mHeight));
			g.SetBlendMode(.Premultiplied);
			g.DrawTexture(result.mTarget.mColor,
				Rect((float)frame.mX - mOriginX, (float)frame.mY - mOriginY, (float)frame.mWidth, (float)frame.mHeight),
				Rect(0, 0, (float)frame.mWidth, (float)frame.mHeight),
				Color(opacity, opacity, opacity, opacity));
			g.SetBlendMode(.Alpha);
			if (element.bHasClip)
				g.PopClip();
		}
		mPool.Release(result);
		if (result != frame.mSurface)
			mPool.Release(frame.mSurface);
	}

	// Blur-behind: copy the target, crop the area behind the element, run the effects on the crop, write the result back.
	void ApplyBackdrop(Element element, GroupFrame frame)
	{
		let g = mGraphics;
		g.Flush();
		let current = CurrentTarget();
		if (current == null)
			return;

		let scratch = mPool.Acquire(mTargetWidth, mTargetHeight) as JunoSurface;
		let region = mPool.Acquire(frame.mWidth, frame.mHeight) as JunoSurface;
		if (scratch == null || region == null)
		{
			if (scratch != null) mPool.Release(scratch);
			if (region != null) mPool.Release(region);
			return;
		}

		Juno.CopyTexture(g.mDevice, scratch.mTarget.mColor.mHandle, current.mColor.mHandle);

		let srcX = (float)frame.mX - mOriginX;
		let srcY = (float)frame.mY - mOriginY;
		g.PushRenderTarget(region.mTarget);
		g.SetBlendMode(.Opaque);
		g.DrawTexture(scratch.mTarget.mColor, Rect(0, 0, (float)frame.mWidth, (float)frame.mHeight), Rect(srcX, srcY, (float)frame.mWidth, (float)frame.mHeight), Color(255, 255, 255, 255));
		g.SetBlendMode(.Alpha);
		g.PopRenderTarget();
		mPool.Release(scratch);

		let result = RunEffects(element, region) as JunoSurface;
		let inner = element.mWorldBounds;
		if (result != null)
		{
			// Only the element's own box is replaced, not the padding.
			let dest = Rect(inner.mX - mOriginX, inner.mY - mOriginY, inner.mWidth, inner.mHeight);
			let src = Rect(inner.mX - (float)frame.mX, inner.mY - (float)frame.mY, inner.mWidth, inner.mHeight);
			if (element.bHasClip)
				g.PushClip(Rect(element.mClip.mX - mOriginX, element.mClip.mY - mOriginY, element.mClip.mWidth, element.mClip.mHeight));
			g.SetBlendMode(.Opaque);
			g.DrawTexture(result.mTarget.mColor, dest, src, Color(255, 255, 255, 255));
			g.SetBlendMode(.Alpha);
			if (element.bHasClip)
				g.PopClip();
			mPool.Release(result);
			if (result != region)
				mPool.Release(region);
		}
		else
		{
			mPool.Release(region);
		}
	}

	// The render target currently drawn into (scene or innermost group surface); null when drawing straight to the back buffer.
	RenderTarget CurrentTarget()
	{
		for (var i = mGroups.Count - 1; i >= 0; i--)
		{
			if (mGroups[i].mSurface != null)
				return mGroups[i].mSurface.mTarget;
		}
		return mSceneTarget;
	}

	RenderTarget mSceneTarget;
}
