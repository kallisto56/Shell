namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Widgets;
using Shell.Elements;
using Shell.Layout;
using Shell.Composition;

// Headless checks of the element system: layout modes, incremental layout, world state, render lists, layout hierarchy,
// template content, path geometry. No window, no GPU: the layout system runs without text or image measurers.
// Call ElementSmokeTests.Run(sink) from any host; failures are reported as errors with code TEST.
static class ElementSmokeTests
{
	class Harness
	{
		public RuntimeContext mContext;
		public ShellKernel mKernel;
		public WidgetRuntime mWidgets;
		public ContainerWidget mRoot;
		public ElementTree mTree;
		public Element mSkin;

		public this(float x = 0, float y = 0, float width = 400, float height = 300)
		{
			mContext = new RuntimeContext();
			mKernel = new ShellKernel(mContext);
			mWidgets = new WidgetRuntime(mKernel);
			mRoot = mWidgets.CreateRoot(width, height);
			mRoot.SetBounds(RectF(x, y, width, height));
			mTree = mRoot.mElements;
			mSkin = mTree.CreateElement(.Container);
			mTree.Attach(mSkin, null);
		}

		public ~this()
		{
			mWidgets.Shutdown();
			delete mWidgets;
			delete mKernel;
			delete mContext;
		}

		public void Tick() => mKernel.Tick(0.016);

		public Element Add(Element parent, ElementKind kind = .Container)
		{
			let element = mTree.CreateElement(kind);
			mTree.Attach(element, parent);
			return element;
		}

		public Element Fixed(Element parent, float width, float height)
		{
			let element = Add(parent);
			Set(element, ElementTypes.sWidthMode, "Fixed");
			Set(element, ElementTypes.sHeightMode, "Fixed");
			element.SetProperty(ElementTypes.sWidth, Value.FromFloat(width));
			element.SetProperty(ElementTypes.sHeight, Value.FromFloat(height));
			return element;
		}

		public void Set(Element element, PropertyDescriptor property, StringView enumCase)
		{
			element.SetProperty(property, Value.FromEnum(enumCase));
		}
	}

	static void Check(bool condition, StringView message, DiagnosticSink sink, ref int failures)
	{
		if (!condition)
		{
			failures++;
			sink.Error("TEST", message);
		}
	}

	static bool Near(float a, float b) => Math.Abs(a - b) < 0.01f;

	static public int Run(DiagnosticSink sink)
	{
		int failures = 0;
		TestStack(sink, ref failures);
		TestGridAndAnchor(sink, ref failures);
		TestAlignmentAndMargins(sink, ref failures);
		TestIncrementalLayout(sink, ref failures);
		TestWorldState(sink, ref failures);
		TestRenderLists(sink, ref failures);
		TestLayoutParent(sink, ref failures);
		TestTemplate(sink, ref failures);
		TestPathGeometry(sink, ref failures);
		return failures;
	}

	static void TestStack(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness();
		h.Set(h.mSkin, ElementTypes.sLayoutMode, "Stack");
		h.mSkin.SetProperty(ElementTypes.sSpacing, Value.FromFloat(5));
		let a = h.Fixed(h.mSkin, 100, 20);
		let b = h.Fixed(h.mSkin, 100, 30);
		let c = h.Fixed(h.mSkin, 100, 40);
		h.Tick();

		Check(Near(a.mArranged.mY, 0) && Near(b.mArranged.mY, 25) && Near(c.mArranged.mY, 60), "vertical stack places children below each other with spacing", sink, ref failures);
		Check(Near(b.mArranged.mWidth, 100) && Near(b.mArranged.mHeight, 30), "stack children keep their fixed size", sink, ref failures);

		// Fill children share the remaining space by weight.
		b.SetProperty(ElementTypes.sHeightMode, Value.FromEnum("Fill"));
		c.SetProperty(ElementTypes.sHeightMode, Value.FromEnum("Fill"));
		h.Tick();
		let expected = (300.0f - 20 - 10) * 0.5f;
		Check(Near(b.mArranged.mHeight, expected) && Near(c.mArranged.mHeight, expected), "Fill children share the remaining stack space", sink, ref failures);

		// Hidden children take no space.
		b.SetProperty(ElementTypes.sVisible, Value.FromBool(false));
		h.Tick();
		Check(Near(c.mArranged.mY, 25) && Near(c.mArranged.mHeight, 300.0f - 20 - 5), "a hidden child leaves no gap", sink, ref failures);
	}

	static void TestGridAndAnchor(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness();
		h.Set(h.mSkin, ElementTypes.sLayoutMode, "Grid");
		h.mSkin.SetProperty(ElementTypes.sColumns, Value.FromString("100,*"));
		h.mSkin.SetProperty(ElementTypes.sRows, Value.FromString("auto,*"));
		let a = h.Fixed(h.mSkin, 50, 20);
		let b = h.Add(h.mSkin);
		b.SetProperty(ElementTypes.sGridColumn, Value.FromInt(1));
		b.SetProperty(ElementTypes.sGridRow, Value.FromInt(1));
		h.Set(b, ElementTypes.sHorizontalAlignment, "Stretch");
		h.Set(b, ElementTypes.sVerticalAlignment, "Stretch");
		h.Tick();

		Check(Near(a.mArranged.mX, 0) && Near(a.mArranged.mY, 0), "grid cell (0,0) is at the origin", sink, ref failures);
		Check(Near(b.mArranged.mX, 100) && Near(b.mArranged.mY, 20), "grid cell (1,1) starts after the fixed column and the auto row", sink, ref failures);
		Check(Near(b.mArranged.mWidth, 300) && Near(b.mArranged.mHeight, 280), "star tracks take the remaining space", sink, ref failures);

		let h2 = scope Harness();
		let anchored = h2.Add(h2.mSkin);
		h2.Set(h2.mSkin, ElementTypes.sLayoutMode, "Anchor");
		anchored.SetProperty(ElementTypes.sAnchorLeft, Value.FromBool(true));
		anchored.SetProperty(ElementTypes.sAnchorRight, Value.FromBool(true));
		anchored.SetProperty(ElementTypes.sMargin, Value.FromRect(10, 0, 30, 0));
		h2.Set(anchored, ElementTypes.sHeightMode, "Fixed");
		anchored.SetProperty(ElementTypes.sHeight, Value.FromFloat(40));
		h2.Tick();
		Check(Near(anchored.mArranged.mX, 10) && Near(anchored.mArranged.mWidth, 360), "left + right anchors stretch between the margins", sink, ref failures);
	}

	static void TestAlignmentAndMargins(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness();
		let child = h.Fixed(h.mSkin, 100, 50);
		h.Set(child, ElementTypes.sHorizontalAlignment, "Center");
		h.Set(child, ElementTypes.sVerticalAlignment, "End");
		child.SetProperty(ElementTypes.sMargin, Value.FromRect(0, 0, 0, 10));
		h.Tick();
		Check(Near(child.mArranged.mX, 150) && Near(child.mArranged.mY, 300 - 10 - 50), "alignment places the child inside its slot, margins reduce it", sink, ref failures);
	}

	static void TestIncrementalLayout(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness();
		h.Set(h.mSkin, ElementTypes.sLayoutMode, "Stack");
		let first = h.Add(h.mSkin);
		h.Set(first, ElementTypes.sLayoutMode, "Stack");
		let leaf = h.Fixed(first, 10, 10);
		Element[8] others = default;
		for (int i < 8)
			others[i] = h.Fixed(h.mSkin, 20, 20);
		h.Tick();
		Check(h.mWidgets.mLayout.mTreesLaidOut == 1, "the first frame lays the tree out", sink, ref failures);

		h.Tick();
		Check(h.mWidgets.mLayout.mTreesLaidOut == 0 && h.mWidgets.mLayout.mMeasured == 0 && h.mWidgets.mLayout.mArranged == 0, "a second frame without changes does no layout work", sink, ref failures);

		leaf.SetProperty(ElementTypes.sWidth, Value.FromFloat(30));
		h.Tick();
		Check(Near(leaf.mArranged.mWidth, 30), "the changed leaf got its new size", sink, ref failures);
		Check(h.mWidgets.mLayout.mMeasured <= 4, "only the changed branch is measured again", sink, ref failures);
	}

	static void TestWorldState(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness(50, 60, 400, 300);
		h.Set(h.mSkin, ElementTypes.sLayoutMode, "Stack");
		let spacer = h.Fixed(h.mSkin, 10, 40);
		let child = h.Fixed(h.mSkin, 100, 20);
		child.SetProperty(ElementTypes.sPosition, Value.FromVector2(5, 7));
		child.SetProperty(ElementTypes.sOpacity, Value.FromFloat(0.5f));
		h.Tick();
		Check(Near(child.mWorldBounds.mX, 55) && Near(child.mWorldBounds.mY, 60 + 40 + 7), "world bounds include the widget origin, layout position and Position", sink, ref failures);
		Check(Near(child.mEffectiveOpacity, 0.5f), "opacity is inherited as a product", sink, ref failures);

		child.SetProperty(ElementTypes.sScale, Value.FromVector2(2, 2));
		h.Tick();
		Check(Near(child.mWorldBounds.mWidth, 200) && Near(child.mWorldBounds.mHeight, 40), "scale changes the world bounds around the pivot", sink, ref failures);

		h.mRoot.SetBounds(RectF(70, 60, 400, 300));
		h.Tick();
		Check(Near(spacer.mWorldBounds.mX, 70), "moving the widget moves its elements without a layout pass", sink, ref failures);
	}

	static void TestRenderLists(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness();
		let content = h.Add(h.mSkin);
		let overlay = h.Add(h.mSkin);
		overlay.mLayer = h.mTree.FindLayerByRole(.Overlay).mId;
		let under = h.Add(h.mSkin);
		under.mLayer = h.mTree.FindLayerByRole(.Underlay).mId;
		h.mTree.BumpStructure();

		h.mTree.EnsureRenderLists();
		bool bOverlayInPost = false;
		for (let item in h.mTree.mRenderPost)
		{
			if (item.mElement == overlay.mHandle)
				bOverlayInPost = true;
		}
		bool bUnderBeforeContent = false;
		int underIndex = -1;
		int contentIndex = -1;
		for (int i < h.mTree.mRenderPre.Count)
		{
			let item = h.mTree.mRenderPre[i];
			if (item.mElement == under.mHandle) underIndex = i;
			if (item.mElement == content.mHandle) contentIndex = i;
		}
		bUnderBeforeContent = underIndex >= 0 && contentIndex > underIndex;
		Check(bOverlayInPost, "overlay layer content is drawn after the widget's children", sink, ref failures);
		Check(bUnderBeforeContent, "underlay content is drawn before the main content", sink, ref failures);

		let rebuilds = h.mTree.mRebuildCount;
		h.mTree.EnsureRenderLists();
		Check(h.mTree.mRebuildCount == rebuilds, "render lists are cached while the structure is unchanged", sink, ref failures);
		content.SetProperty(ElementTypes.sVisible, Value.FromBool(false));
		h.mTree.EnsureRenderLists();
		Check(h.mTree.mRebuildCount == rebuilds + 1, "a visibility change rebuilds the render lists", sink, ref failures);

		// A removed layer sends its elements to the Content layer.
		h.mTree.RemoveLayer(h.mTree.FindLayerByRole(.Underlay).mId);
		Check(under.mLayer == h.mTree.FindLayerByRole(.Content).mId, "elements of a removed layer move to Content", sink, ref failures);
	}

	static void TestLayoutParent(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness();
		let host = h.Fixed(h.mSkin, 100, 100);
		host.SetProperty(ElementTypes.sPosition, Value.FromVector2(200, 100));
		let other = h.Add(h.mSkin);
		let moved = h.Fixed(other, 10, 10);
		h.Tick();
		Check(Near(moved.mWorldBounds.mX, 0), "by default an element lives in its owner's space", sink, ref failures);

		Check(h.mTree.SetLayoutParent(moved, host), "a layout parent can be set", sink, ref failures);
		h.Tick();
		Check(Near(moved.mWorldBounds.mX, 200) && Near(moved.mWorldBounds.mY, 100), "a layout parent defines the coordinate space and its transform is inherited", sink, ref failures);
		Check(!h.mTree.SetLayoutParent(host, moved), "a layout cycle is rejected", sink, ref failures);

		// The layout parent disappears: the element falls back to its owner.
		host.RequestDestroy();
		h.mContext.FlushDestruction();
		h.Tick();
		Check(Near(moved.mWorldBounds.mX, 0), "an element whose layout parent was destroyed falls back to its owner", sink, ref failures);
	}

	static void TestTemplate(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness();
		let template = scope ElementNodeData();
		template.mId = StableId(500);
		let childA = new ElementNodeData();
		childA.mId = StableId(501);
		let childB = new ElementNodeData();
		childB.mId = StableId(502);
		template.mChildren.Add(childA);
		template.mChildren.Add(childB);

		let instantiator = h.mWidgets.mInstantiator;
		let host = h.Add(h.mSkin);
		host.mTemplate = template;

		instantiator.SetExists(host, true);
		Check(host.mChildren.Count == 2 && host.bTemplateInstantiated, "template content is created", sink, ref failures);
		let firstId = host.mChildren[0].mStableId;
		Check(firstId == StableId.Combine(host.mStableId, StableId(501)), "template instances get ids derived from owner and template node", sink, ref failures);

		instantiator.SetExists(host, false);
		h.mContext.FlushDestruction();
		Check(host.mChildren.Count == 0 && !host.bTemplateInstantiated, "template content is destroyed", sink, ref failures);

		instantiator.SetExists(host, true);
		Check(host.mChildren.Count == 2 && host.mChildren[0].mStableId == firstId, "re-created template content keeps the same ids", sink, ref failures);
	}

	static void TestPathGeometry(DiagnosticSink sink, ref int failures)
	{
		if (PathGeometry.Parse("M0 0 L10 0 L10 10 L0 10 Z") case .Ok(let square))
		{
			Check(square.mContours.Count == 1 && square.mContours[0].bClosed, "a square path has one closed contour", sink, ref failures);
			Check(Near(square.mBounds.mWidth, 10) && Near(square.mBounds.mHeight, 10), "path bounds are computed", sink, ref failures);
			let indices = square.mContours[0].GetFillIndices();
			Check(indices != null && indices.Count == 6, "a quad triangulates into two triangles", sink, ref failures);
			delete square;
		}
		else
		{
			Check(false, "a valid path parses", sink, ref failures);
		}

		if (PathGeometry.Parse("M0 0 Q 5 10 10 0") case .Ok(let curve))
		{
			Check(curve.mContours[0].mPoints.Count == 17, "a quadratic curve is flattened into 16 segments", sink, ref failures);
			delete curve;
		}
		else
		{
			Check(false, "a curve path parses", sink, ref failures);
		}

		bool bRejected = false;
		if (PathGeometry.Parse("M0 0 X 5") case .Err)
			bRejected = true;
		Check(bRejected, "an unknown path command is rejected", sink, ref failures);

		let tracks = scope List<GridTrack>();
		Check(GridTracks.Parse("100, auto, 2*", tracks) && tracks.Count == 3 && tracks[2].mKind == .Star && Near(tracks[2].mValue, 2), "grid track definitions parse", sink, ref failures);
	}
}
