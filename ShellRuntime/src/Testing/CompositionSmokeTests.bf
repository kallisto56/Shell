namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Widgets;
using Shell.Elements;
using Shell.Composition;
using Shell.Styling;
using Shell.Editor;

// Headless checks of Stage 5: UserWidget instances (independence, exposed members, overrides, propagation, missing / cyclic
// definitions), the style system (components, states, tokens, arbitration, themes), the layer / hierarchy editor and "extract UserWidget".
// Call CompositionSmokeTests.Run(sink); failures are reported as errors with code TEST.
static class CompositionSmokeTests
{
	class Counter : IEventListener
	{
		public int mCount;

		public void OnEvent(RuntimeObject source, EventDescriptor ev, Span<Value> arguments)
		{
			mCount++;
		}
	}

	class Harness
	{
		public RuntimeContext mContext;
		public ShellKernel mKernel;
		public WidgetRuntime mWidgets;
		public ShellProject mProject;
		public ContainerWidget mRoot;

		public this()
		{
			mContext = new RuntimeContext();
			mKernel = new ShellKernel(mContext);
			mWidgets = new WidgetRuntime(mKernel);
			mProject = new ShellProject();
			mRoot = mWidgets.CreateRoot(800, 600);
		}

		public ~this()
		{
			mWidgets.Shutdown();
			delete mWidgets;
			delete mKernel;
			delete mProject;
			delete mContext;
		}

		public void Tick() => mKernel.Tick(0.016);
		public StringPool Pool => mProject.mStrings;
	}

	static void Check(bool condition, StringView message, DiagnosticSink sink, ref int failures)
	{
		if (!condition)
		{
			failures++;
			sink.Error("TEST", message);
		}
	}

	static void Prop(WidgetNodeData node, StringPool pool, StringView name, Value value)
	{
		PropertyValueData assignment = default;
		assignment.mName = pool.Intern(name);
		assignment.mValue = value;
		node.mProperties.Add(assignment);
	}

	static WidgetNodeData Node(StringPool pool, StringView type, uint64 id)
	{
		let node = new WidgetNodeData();
		node.mId = StableId(id);
		node.mTypeName = pool.Intern(type);
		return node;
	}

	static ElementNodeData Shape(uint64 id)
	{
		let element = new ElementNodeData();
		element.mId = StableId(id);
		element.mKind = .Shape;
		return element;
	}

	static uint64 sExposedCounter;

	static ExposedMember Expose(ExposedKind kind, StringView publicName, uint64 target, StringView member, ValueKind valueKind, bool writable, StringPool pool)
	{
		let exposed = new ExposedMember();
		exposed.mId = StableId(9000 + (++sExposedCounter));
		exposed.mPublicName.Set(publicName);
		exposed.mKind = kind;
		exposed.mValueKind = valueKind;
		exposed.mInnerTarget = StableId(target);
		exposed.mInnerMember = pool.Intern(member);
		exposed.bWritable = writable;
		return exposed;
	}

	// "Card": a container with a skin element (101) and a text box (102); exposes Text, Submitted and the element's Fill.
	static CompositionDefinition MakeCard(Harness h, uint64 id)
	{
		let pool = h.Pool;
		let card = new CompositionDefinition();
		card.mId = StableId(id);
		card.mName.Set("Card");
		card.mRevision = 1;
		card.mRoot = Node(pool, "Container", 100);
		card.mRoot.mSkin = new ElementTreeData();
		card.mRoot.mSkin.mRoot = Shape(101);
		let @box = Node(pool, "TextBox", 102);
		Prop(@box, pool, "Bounds", Value.FromRect(10, 10, 200, 24));
		card.mRoot.mChildren.Add(@box);
		card.mExposed.Add(Expose(.Property, "Text", 102, "Text", .String, true, pool));
		card.mExposed.Add(Expose(.Event, "Submitted", 102, "Submitted", .None, false, pool));
		card.mExposed.Add(Expose(.Property, "Back", 101, "Fill", .Color, true, pool));
		return card;
	}

	static WidgetNodeData InstanceNode(Harness h, uint64 id, uint64 definition)
	{
		let node = new WidgetNodeData();
		node.mId = StableId(id);
		node.mSourceDefinition = StableId(definition);
		return node;
	}

	static public int Run(DiagnosticSink sink)
	{
		int failures = 0;
		TestInstances(sink, ref failures);
		TestPropagation(sink, ref failures);
		TestMissingAndCyclic(sink, ref failures);
		TestStyles(sink, ref failures);
		TestLayerEditor(sink, ref failures);
		TestExtraction(sink, ref failures);
		return failures;
	}

	static void TestInstances(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness();
		let pool = h.Pool;
		h.mProject.mCompositions.Add(MakeCard(h, 1), h.mContext.mDiagnostics);

		let main = new CompositionDefinition();
		main.mId = StableId(2);
		main.mName.Set("Main");
		main.mRevision = 1;
		main.mRoot = Node(pool, "Container", 50);
		let a = InstanceNode(h, 1001, 1);
		Prop(a, pool, "Text", Value.FromString(pool.Intern("hello")));
		let b = InstanceNode(h, 1002, 1);
		let entry = new OverrideEntry();
		entry.mPath.Add(StableId(102));
		entry.mProperty = pool.Intern("PlaceholderText");
		entry.mValue = Value.FromString(pool.Intern("type here"));
		a.mOverrides.Add(entry);
		main.mRoot.mChildren.Add(a);
		main.mRoot.mChildren.Add(b);
		h.mProject.mCompositions.Add(main, h.mContext.mDiagnostics);

		h.mWidgets.UseProject(h.mProject);
		// WARNING 168: The variable 'host' is assigned but its value is never used
		let host = h.mWidgets.InstantiateDefinition(StableId(2), h.mRoot);
		h.Tick();

		let ia = h.mContext.FindByStableId(StableId(1001)) as UserWidget;
		let ib = h.mContext.FindByStableId(StableId(1002)) as UserWidget;
		Check(ia != null && ib != null && !ia.bMissing, "instances of a nested definition are created", sink, ref failures);

		let innerA = h.mContext.FindByStableId(StableId.Combine(StableId(1001), StableId(102))) as TextBox;
		let innerB = h.mContext.FindByStableId(StableId.Combine(StableId(1002), StableId(102))) as TextBox;
		Check(innerA != null && innerB != null && innerA != innerB, "every instance has its own copy of the content (scoped ids)", sink, ref failures);

		let text = ia.GetDescriptor().FindProperty("Text");
		Check(text != null && ia.GetProperty(text).AsString() == "hello" && innerA.mTextView == "hello", "an instance value for an exposed property reaches the inner widget", sink, ref failures);
		Check(ib.GetProperty(ib.GetDescriptor().FindProperty("Text")).AsString().IsEmpty, "other instances are not affected", sink, ref failures);

		innerB.SetProperty(TextBox.sText, Value.FromString(h.mContext.mStrings.InternTransient("typed")));
		Check(ib.GetProperty(ib.GetDescriptor().FindProperty("Text")).AsString() == "typed", "inner changes are mirrored to the exposed property", sink, ref failures);

		ia.SetProperty(text, Value.FromString(h.mContext.mStrings.InternTransient("written")));
		Check(innerA.mTextView == "written", "writing an exposed property is written through", sink, ref failures);

		let submitted = ia.GetDescriptor().FindEvent("Submitted");
		let counter = scope Counter();
		ia.Subscribe(submitted, counter);
		innerA.RaiseEvent(TextBox.sSubmitted);
		Check(counter.mCount == 1, "an exposed event is raised on the instance", sink, ref failures);

		Check(innerA.GetProperty(TextBox.sPlaceholder).AsString() == "type here", "a per-instance override reaches an inner object", sink, ref failures);
		Check(innerB.GetProperty(TextBox.sPlaceholder).AsString().IsEmpty, "an override only affects its own instance", sink, ref failures);
	}

	static void TestPropagation(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness();
		let pool = h.Pool;
		let card = MakeCard(h, 1);
		h.mProject.mCompositions.Add(card, h.mContext.mDiagnostics);
		let main = new CompositionDefinition();
		main.mId = StableId(2);
		main.mRevision = 1;
		main.mRoot = Node(pool, "Container", 50);
		let a = InstanceNode(h, 1001, 1);
		Prop(a, pool, "Text", Value.FromString(pool.Intern("keep")));
		main.mRoot.mChildren.Add(a);
		main.mRoot.mChildren.Add(InstanceNode(h, 1002, 1));
		h.mProject.mCompositions.Add(main, h.mContext.mDiagnostics);
		h.mWidgets.UseProject(h.mProject);
		h.mWidgets.InstantiateDefinition(StableId(2), h.mRoot);
		h.Tick();

		let ia = h.mContext.FindByStableId(StableId(1001)) as UserWidget;
		Check(ia.mContent != null && ia.mContent.mChildren.Count == 1, "the content has the authored structure", sink, ref failures);

		// Edit the definition: one more inner widget, one more exposed property; revision changes.
		card.mRoot.mChildren.Add(Node(pool, "Container", 103));
		card.mExposed.Add(Expose(.Property, "Placeholder", 102, "PlaceholderText", .String, true, pool));
		card.mRevision++;
		h.Tick();

		let ia2 = h.mContext.FindByStableId(StableId(1001)) as UserWidget;
		let ib2 = h.mContext.FindByStableId(StableId(1002)) as UserWidget;
		Check(ia2 == ia, "propagation keeps the identity of the instance", sink, ref failures);
		Check(ia.mContent.mChildren.Count == 2 && ib2.mContent.mChildren.Count == 2, "a definition edit reaches all instances in the same frame", sink, ref failures);
		Check(ia.GetDescriptor().FindProperty("Placeholder") != null, "a new exposed member appears on existing instances", sink, ref failures);
		Check(ia.GetProperty(ia.GetDescriptor().FindProperty("Text")).AsString() == "keep", "saved instance values survive a rebuild", sink, ref failures);
		Check(h.mWidgets.mUserWidgets.mRebuilt == 0, "an unchanged frame rebuilds nothing", sink, ref failures);
	}

	static void TestMissingAndCyclic(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness();
		let pool = h.Pool;
		let loop = new CompositionDefinition();
		loop.mId = StableId(5);
		loop.mName.Set("Loop");
		loop.mRevision = 1;
		loop.mRoot = Node(pool, "Container", 500);
		loop.mRoot.mChildren.Add(InstanceNode(h, 501, 5));
		h.mProject.mCompositions.Add(loop, h.mContext.mDiagnostics);

		let main = new CompositionDefinition();
		main.mId = StableId(6);
		main.mRevision = 1;
		main.mRoot = Node(pool, "Container", 600);
		main.mRoot.mChildren.Add(InstanceNode(h, 601, 404));      // does not exist
		main.mRoot.mChildren.Add(InstanceNode(h, 602, 5));        // cyclic
		h.mProject.mCompositions.Add(main, h.mContext.mDiagnostics);
		h.mWidgets.UseProject(h.mProject);
		h.mWidgets.InstantiateDefinition(StableId(6), h.mRoot);
		h.Tick();

		let missing = h.mContext.FindByStableId(StableId(601)) as UserWidget;
		let cyclic = h.mContext.FindByStableId(StableId(602)) as UserWidget;
		Check(missing != null && missing.bMissing && missing.mContent == null, "an instance of a missing definition is a placeholder", sink, ref failures);
		Check(cyclic != null && cyclic.bMissing, "a definition that contains itself is refused with a placeholder", sink, ref failures);
		Check(missing.GetProperty(UserWidget.sIsMissing).AsBool(), "placeholders report IsMissing", sink, ref failures);
	}

	static void TestStyles(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness();
		let pool = h.Pool;

		let definition = new CompositionDefinition();
		definition.mId = StableId(1);
		definition.mRevision = 1;
		definition.mRoot = Node(pool, "Container", 10);
		let button = Node(pool, "Button", 11);
		button.mSkin = new ElementTreeData();
		button.mSkin.mRoot = Shape(12);
		definition.mRoot.mChildren.Add(button);
		h.mProject.mCompositions.Add(definition, h.mContext.mDiagnostics);

		// themes with a token
		let light = new Theme();
		light.mId = StableId(70);
		light.mName.Set("Light");
		let width = new DesignToken();
		width.mName.Set("stroke.width");
		width.mKind = .Float;
		width.mValue = Value.FromFloat(2);
		light.mTokens.Add(width);
		let dark = new Theme();
		dark.mId = StableId(71);
		dark.mName.Set("Dark");
		dark.mParent = light.mId;
		let darkWidth = new DesignToken();
		darkWidth.mName.Set("stroke.width");
		darkWidth.mKind = .Float;
		darkWidth.mValue = Value.FromFloat(5);
		dark.mTokens.Add(darkWidth);
		h.mProject.mThemes.Add(light);
		h.mProject.mThemes.Add(dark);

		// style of the type "Button": red by default, blue while hovered, stroke width from the theme
		let style = new ComponentStyle();
		style.mId = StableId(80);
		style.mWidgetType = pool.Intern("Button");
		let normal = new StyleRule();
		normal.mId = StableId(81);
		StyleSetter fill = default;
		fill.mTarget = StableId(12);
		fill.mProperty = pool.Intern("Fill");
		fill.mValue = Value.FromColor(1, 0, 0, 1);
		normal.mSetters.Add(fill);
		StyleSetter stroke = default;
		stroke.mTarget = StableId(12);
		stroke.mProperty = pool.Intern("StrokeWidth");
		stroke.mToken = pool.Intern("stroke.width");
		normal.mSetters.Add(stroke);
		style.mRules.Add(normal);
		let hover = new StyleRule();
		hover.mId = StableId(82);
		hover.mCondition.mRequired = .Hovered;
		StyleSetter blue = default;
		blue.mTarget = StableId(12);
		blue.mProperty = pool.Intern("Fill");
		blue.mValue = Value.FromColor(0, 0, 1, 1);
		hover.mSetters.Add(blue);
		style.mRules.Add(hover);
		h.mProject.mStyles.Add(style);

		h.mWidgets.UseProject(h.mProject);
		h.mWidgets.InstantiateDefinition(StableId(1), h.mRoot);
		h.Tick();

		let widget = h.mContext.FindByStableId(StableId.Combine(StableId(1), StableId(11))) as Widget;
		Check(widget != null, "the styled widget exists", sink, ref failures);
		Element element = null;
		if (widget != null)
			element = widget.mElements.mRoot;

		Check(element != null && element.GetProperty(ElementTypes.sFill).mX == 1 && element.GetProperty(ElementTypes.sFill).mZ == 0, "the component style sets the default look", sink, ref failures);
		Check(element != null && element.GetProperty(ElementTypes.sStrokeWidth).AsFloat() == 2, "a design token of the active theme is applied", sink, ref failures);

		widget.SetHovered(true);
		h.Tick();
		Check(element.GetProperty(ElementTypes.sFill).mZ == 1, "a state style applies while the state holds", sink, ref failures);
		widget.SetHovered(false);
		h.Tick();
		Check(element.GetProperty(ElementTypes.sFill).mX == 1 && element.GetProperty(ElementTypes.sFill).mZ == 0, "it is removed again when the state ends", sink, ref failures);

		element.SetProperty(ElementTypes.sFill, Value.FromColor(0, 1, 0, 1));
		widget.SetHovered(true);
		h.Tick();
		Check(element.GetProperty(ElementTypes.sFill).mY == 1, "an authored value wins over component and state styles", sink, ref failures);

		h.mWidgets.mThemes.SetActive(StableId(71));
		h.Tick();
		Check(element.GetProperty(ElementTypes.sStrokeWidth).AsFloat() == 5, "switching the theme restyles", sink, ref failures);
	}

	static ElementTreeData MakeSkin(StringPool pool)
	{
		let tree = new ElementTreeData();
		let underlay = new LayerDefinition();
		underlay.mId = StableId(301); underlay.mName.Set("Underlay"); underlay.mRole = .Underlay; underlay.mOrder = -100;
		let content = new LayerDefinition();
		content.mId = StableId(302); content.mName.Set("Content"); content.mRole = .Content; content.mOrder = 0; content.bEssential = true;
		let overlay = new LayerDefinition();
		overlay.mId = StableId(303); overlay.mName.Set("Overlay"); overlay.mRole = .Overlay; overlay.mOrder = 100;
		tree.mLayers.Add(underlay);
		tree.mLayers.Add(content);
		tree.mLayers.Add(overlay);
		tree.mRoot = Shape(310);
		let background = Shape(311);
		background.mLayer = underlay.mId;
		let caret = Shape(312);
		caret.mLayer = overlay.mId;
		caret.bEssential = true;
		tree.mRoot.mChildren.Add(background);
		tree.mRoot.mChildren.Add(caret);
		return tree;
	}

	static void TestLayerEditor(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness();
		let definition = new CompositionDefinition();
		definition.mId = StableId(1);
		definition.mRevision = 1;
		definition.mRoot = Node(h.Pool, "TextBox", 300);
		definition.mRoot.mSkin = MakeSkin(h.Pool);
		let session = scope DefinitionEditSession(definition, h.mContext.mDiagnostics);
		let stack = scope CommandStack();
		let editor = scope HierarchyEditor(session, definition.mRoot.mSkin, stack, h.mContext.mIds);
		let tree = definition.mRoot.mSkin;

		let rows = scope List<LayerRow>();
		LayerEditModel.Build(tree, rows);
		Check(rows.Count == 3 && rows[0].mRole == .Underlay && rows[0].mEntries.Count == 1 && rows[1].mEntries.Count == 1 && rows[2].mEntries.Count == 1, "the layer view lists elements per layer in draw order", sink, ref failures);
		rows.ClearAndDeleteItems();

		Check(editor.RemoveLayer(StableId(302)) == .Essential, "the Content layer cannot be removed", sink, ref failures);
		Check(editor.MoveLayer(StableId(301), 2) == .RoleOrder, "Underlay cannot move in front of Content", sink, ref failures);
		Check(editor.DeleteElement(StableId(312)) == .Essential, "an essential element cannot be deleted", sink, ref failures);
		Check(editor.DeleteElement(StableId(310)) == .InvalidTarget, "the skin root cannot be deleted", sink, ref failures);
		Check(editor.MoveElement(StableId(310), StableId(311), 0) == .InvalidTarget, "the skin root cannot be moved", sink, ref failures);

		let revision = definition.mRevision;
		let added = editor.AddLayer("Glow", 2);
		Check(added case .Ok, "a custom layer can be added between Content and Overlay", sink, ref failures);
		Check(definition.mRevision > revision, "editing bumps the definition revision", sink, ref failures);
		let glow = added.Value;

		Check(editor.SetElementLayer(StableId(311), glow) == .None, "an element can be assigned to the new layer", sink, ref failures);
		Check(editor.MoveElement(StableId(312), StableId(311), 0) == .None, "elements can change owner without changing layer", sink, ref failures);
		Check(editor.MoveElement(StableId(311), StableId(312), 0) == .Cycle, "an element cannot become its own descendant", sink, ref failures);

		Check(editor.RemoveLayer(glow) == .None, "a custom layer can be removed", sink, ref failures);
		Check(tree.mRoot.mChildren.Count >= 1, "removing a layer does not remove elements", sink, ref failures);

		// undo everything back to the start
		while (stack.mCanUndo)
			stack.Undo();
		Check(tree.mLayers.Count == 3 && tree.mRoot.mChildren.Count == 2 && tree.mRoot.mChildren[0].mId == StableId(311), "undo restores layers, ownership and assignments", sink, ref failures);
		let outline = CompositionOutline.Build(definition, h.mProject.mCompositions);
		defer delete outline;
		Check(outline.mRoot != null && outline.FindByPath(StableId(312)) != null && outline.FindByPath(StableId(312)).bEssential, "the outline shows elements with their flags", sink, ref failures);
	}

	static void TestExtraction(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness();
		let pool = h.Pool;
		let definition = new CompositionDefinition();
		definition.mId = StableId(1);
		definition.mName.Set("Main");
		definition.mRevision = 1;
		definition.mRoot = Node(pool, "Container", 50);
		let source = Node(pool, "TextBox", 61);
		Prop(source, pool, "Bounds", Value.FromRect(10, 20, 100, 30));
		let reader = Node(pool, "Container", 62);
		let binding = new BindingDescriptor();
		binding.mId = StableId(900);
		binding.mTargetProperty = pool.Intern("Visible");
		binding.mSource.mKind = .WidgetProperty;
		binding.mSource.mTarget = StableId(61);
		binding.mSource.mMember = pool.Intern("HasSelection");
		reader.mBindings.Add(binding);
		definition.mRoot.mChildren.Add(source);
		definition.mRoot.mChildren.Add(reader);
		h.mProject.mCompositions.Add(definition, h.mContext.mDiagnostics);

		let session = scope DefinitionEditSession(definition, h.mContext.mDiagnostics);
		let selection = scope List<StableId>();
		selection.Add(StableId(61));
		let report = scope ExtractionReport();
		let result = UserWidgetExtractor.Prepare(session, h.mProject.mCompositions, pool, h.mContext.mIds, selection, "Field", report);
		Check((result case .Ok) && report.mIsOk, "extraction of a widget succeeds", sink, ref failures);
		if (result case .Err)
			return;

		let stack = scope CommandStack();
		stack.Execute(result.Value);
		Check(definition.mRoot.mChildren.Count == 2 && definition.mRoot.mChildren[0].mIsInstance, "an instance takes the place of the extracted widget", sink, ref failures);
		let created = h.mProject.mCompositions.Find(definition.mRoot.mChildren[0].mSourceDefinition);
		Check(created != null && created.mRoot == source && created.mName == "Field", "the widget moved into a new definition (no separate prefab type)", sink, ref failures);
		Check(binding.mSource.mTarget == definition.mRoot.mChildren[0].mId && binding.mSource.mMember == "HasSelection", "outside bindings now read the instance's exposed property", sink, ref failures);
		Check(created != null && created.mExposed.Count == 1 && report.mExposedCount == 1, "the property the outside used was exposed", sink, ref failures);
		Check(definition.mRoot.mChildren[0].mProperties.Count == 1 && source.mProperties[0].mValue.mX == 0, "the instance keeps the position, the content starts at the origin", sink, ref failures);

		stack.Undo();
		Check(definition.mRoot.mChildren[0] == source && binding.mSource.mTarget == StableId(61) && h.mProject.mCompositions.Find(created.mId) == null, "undo restores the composition exactly", sink, ref failures);
	}
}
