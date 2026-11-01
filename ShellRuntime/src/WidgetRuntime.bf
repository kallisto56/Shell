namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Widgets;
using Shell.Input;
using Shell.Platform;

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
	public ContainerWidget mRoot;

	public this(ShellKernel kernel, PlatformServices services = null)
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
		kernel.AddSystem(mBindings);
		mContext.mWidgetHost = mHost;
	}

	public ~this()
	{
		mKernel.RemoveSystem(mRouter);
		mKernel.RemoveSystem(mBindings);
		mContext.mWidgetHost = null;
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
