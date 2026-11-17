namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Widgets;
using Shell.Input;
using Shell.Platform;
using Shell.Layout;
using Shell.Composition;
using Shell.Styling;

// Wires the widget layer into a kernel: input queue and router (Input phase), focus manager, widget host, binding resolver and
// binding system (Bindings phase), the widget event queue for Blueprints, and the built-in widget types.
//
//   let kernel = new ShellKernel(context);
//   let widgets = new WidgetRuntime(kernel, services);
//   let root = widgets.CreateRoot(1920, 1080);
//   let button = widgets.Create<Button>(root, RectF(20, 20, 120, 32));
//   widgets.mInput.EnqueuePointer(...);      // from the platform bridge
//   kernel.Tick(dt);
class WidgetRuntime
{
	public ShellKernel mKernel;
	public RuntimeContext mContext;
	public WidgetHost mHost ~ delete _;
	public FocusManager mFocus ~ delete _;
	public InputEventQueue mInput ~ delete _;
	public InputRouter mRouter ~ delete _;
	public EventQueue mEvents ~ delete _;
	public QueuedEventListener mEventForwarder ~ delete _;
	public RuntimeBindingResolver mResolver ~ delete _;
	public BindingSystem mBindings ~ delete _;
	public LayoutSystem mLayout ~ delete _;
	public ElementInstantiator mInstantiator ~ delete _;
	public ThemeManager mThemes ~ delete _;
	public StyleRegistry mStyles ~ delete _;
	public StyleSystem mStyle ~ delete _;
	public WidgetFactory mFactory ~ delete _;
	public UserWidgetTypeFactory mUserTypes ~ delete _;
	public UserWidgetHost mUserWidgets ~ delete _;
	public CompositionInstantiator mComposition ~ delete _;
	public ShellProject mProject;               // the project whose themes, styles and definitions are live (not owned)
	List<WidgetNodeData> mEntryNodes = new .() ~ DeleteContainerAndItems!(_);
	public ContainerWidget mRoot;

	public this(ShellKernel kernel, PlatformServices services = null, ITextMeasurer textMeasurer = null, IImageMeasurer imageMeasurer = null)
	{
		mKernel = kernel;
		mContext = kernel.mContext;
		WidgetLibrary.RegisterTypes(mContext);

		mHost = new WidgetHost(mContext);
		mFocus = new FocusManager(mContext, mHost);
		mHost.mFocus = mFocus;
		if (services != null)
		{
			mHost.mClipboard = services.mClipboard;
			mHost.mTextInput = services.mTextInput;
			mHost.mClock = services.mClock;
		}

		mInput = new InputEventQueue();
		mEvents = new EventQueue(mContext);
		mEventForwarder = new QueuedEventListener(mEvents);
		mResolver = new RuntimeBindingResolver(mContext);
		mBindings = new BindingSystem(mContext, mResolver);
		mRouter = new InputRouter(mContext, mHost, mFocus, mInput);

		kernel.AddSystem(mRouter);
		mLayout = new LayoutSystem(mContext, textMeasurer, imageMeasurer);
		mInstantiator = new ElementInstantiator(mContext, mBindings);
		mThemes = new ThemeManager();
		mStyles = new StyleRegistry();
		mResolver.mThemes = mThemes;
		mStyle = new StyleSystem(mContext, mThemes, mStyles);
		mFactory = new WidgetFactory();
		WidgetLibrary.RegisterFactory(mFactory);
		mUserTypes = new UserWidgetTypeFactory(mContext);
		mUserWidgets = new UserWidgetHost(mContext, mUserTypes, mBindings);
		mComposition = new CompositionInstantiator(mContext, mFactory, mBindings, mInstantiator, mUserWidgets);

		kernel.AddSystem(mStyle);
		kernel.AddSystem(mBindings);
		kernel.AddSystem(mLayout);
		kernel.AddSystem(mUserWidgets);
		mContext.mWidgetHost = mHost;
	}

	public ~this()
	{
		mKernel.RemoveSystem(mRouter);
		mKernel.RemoveSystem(mBindings);
		mKernel.RemoveSystem(mLayout);
		mKernel.RemoveSystem(mStyle);
		mKernel.RemoveSystem(mUserWidgets);
		mContext.mWidgetHost = null;
	}

	// Makes the themes, component styles and UserWidget definitions of a project live. The project is not owned and must outlive the runtime.
	// The first theme becomes active when none is. Definitions edited later (revision change) propagate to their instances automatically.
	public void UseProject(ShellProject project)
	{
		mProject = project;
		for (let theme in project.mThemes)
			mThemes.Add(theme);
		if (!mThemes.mActiveId.mIsValid && project.mThemes.Count > 0)
			mThemes.SetActive(project.mThemes[0].mId);
		for (let style in project.mStyles)
			mStyles.Add(style);
		mUserWidgets.mRegistry = project.mCompositions;
		mUserTypes.mRegistry = project.mCompositions;
	}

	// Creates a live instance of a definition (a UserWidget) below `parent` (null = no parent). The runtime keeps the instance node.
	public UserWidget InstantiateDefinition(StableId definitionId, Widget parent, StableId instanceId = .sNone)
	{
		let node = new WidgetNodeData();
		node.mId = instanceId.mIsValid ? instanceId : mContext.mIds.Next();
		node.mSourceDefinition = definitionId;
		mEntryNodes.Add(node);
		return mUserWidgets.CreateInstance(node, parent, StableId.sNone, 0);
	}

	// Destroys the widget tree (call before the runtime and context are deleted).
	public void Shutdown()
	{
		mFocus.Clear();
		if (mRoot != null)
			mRoot.RequestDestroy();
		mRoot = null;
		mContext.FlushDestruction();
	}

	public T Create<T>(Widget parent, RectF bounds, StableId id = .sNone) where T : Widget, new
	{
		let widget = new T();
		widget.Initialize(mContext, id);
		widget.SetBounds(bounds);
		widget.Activate();
		if (parent != null)
			parent.AddChild(widget);
		return widget;
	}

	// The root fills the window; the router hit-tests from it. Window resizes call Resize().
	public ContainerWidget CreateRoot(float width, float height)
	{
		mRoot = Create<ContainerWidget>(null, RectF(0, 0, width, height));
		mRouter.SetRoot(mRoot);
		mLayout.SetRoot(mRoot);
		mStyle.SetRoot(mRoot);
		return mRoot;
	}

	public void Resize(float width, float height)
	{
		if (mRoot != null)
			mRoot.SetBounds(RectF(0, 0, width, height));
	}

	// Forwards a widget event to the Blueprint event queue (queued, run-to-completion handling in the Blueprints phase).
	public SubscriptionId ForwardToBlueprints(Widget widget, EventDescriptor ev)
	{
		return widget.Subscribe(ev, mEventForwarder);
	}
}
