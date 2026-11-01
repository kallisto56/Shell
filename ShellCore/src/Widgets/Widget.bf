namespace Shell.Widgets;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Elements;
using Shell.Input;
using Shell.Binding;

// Base class of all interactive components. A Widget owns its behavior and meaningful state; how it looks is the job of
// its ElementTree (skin), which only reads the widget's public state through bindings.
//
//   state      : PropertyStore laid out by the widget's TypeDescriptor (read-only state, writable values, computed values)
//   events     : EventDispatcher; widgets raise events described by EventDescriptors (immediately, to all subscribers; a
//                subscriber that wants deferred handling - the Blueprint host - queues them itself)
//   methods    : MethodDescriptors invoked through IMethodHost; arguments are validated centrally, then OnInvokeMethod runs
//   input      : routed by the widget runtime: tunnel (OnPreview*) from the root to the target, then bubble (On*) back up
//   hierarchy  : mParent / mChildren (ownership); a UserWidget instance appears as one Widget with a hidden subtree
//   visuals    : mElements
//
// Widgets are independent of any visual style: removing the skin leaves a fully functional (invisible) control.
abstract class Widget : RuntimeObject, IPropertyHost, IMethodHost, IEventSource, IPropertyChangeListener
{
	public PropertyStore mProperties;
	public EventDispatcher mEvents = new .() ~ delete _;
	public ElementTree mElements;
	public Widget mParent;
	public List<Widget> mChildren = new .() ~ delete _;
	public List<Binding> mBindings = new .() ~ DeleteContainerAndItems!(_);    // owned; registered with the BindingSystem

	public Invalidation mDirty;             // what this widget needs recomputed
	public bool bSubtreeDirty;              // some descendant is dirty (lets traversals skip clean subtrees)

	class AddChildMutation : Mutation
	{
		public Handle mParent;
		public Handle mChild;
		public int mIndex;

		public override void Apply(RuntimeContext context)
		{
			let parent = context.Resolve<Widget>(mParent);
			let child = context.Resolve<Widget>(mChild);
			if (parent != null && child != null && parent.mIsAlive && child.mIsAlive)
				parent.AddChildNow(child, mIndex);
		}
	}

	public abstract TypeDescriptor GetDescriptor();

	protected override void OnInitialize()
	{
		mProperties = new PropertyStore(GetDescriptor(), mContext.mStrings);
		mProperties.mListener = this;
		mElements = new ElementTree(mContext, this);
	}

	protected override void OnDestroy()
	{
		delete mElements;
		delete mProperties;
		mElements = null;
		mProperties = null;
	}

	protected override void OnDestroyRequested()
	{
		for (let child in mChildren)
			child.RequestDestroy();
		if (mElements.mRoot != null)
			mElements.mRoot.RequestDestroy();
	}

	public override void DetachFromOwner()
	{
		if (mParent != null)
		{
			mParent.mChildren.Remove(this);
			mParent = null;
		}
	}

	// ---- Hierarchy ----------------------------------------------------------------------------------------------

	// Applied immediately, or at the next Commit while a traversal (input routing, update, render) is running.
	public void AddChild(Widget child, int index = -1)
	{
		if (mContext.mTraversal.mIsTraversing)
		{
			let mutation = new AddChildMutation();
			mutation.mParent = mHandle;
			mutation.mChild = child.mHandle;
			mutation.mIndex = index;
			mContext.mMutations.Defer(mutation);
			return;
		}
		AddChildNow(child, index);
	}

	void AddChildNow(Widget child, int index)
	{
		if (child.mParent != null)
			child.mParent.mChildren.Remove(child);

		for (Widget ancestor = this; ancestor != null; ancestor = ancestor.mParent)
		{
			if (ancestor == child)
			{
				mContext.mDiagnostics.Error("WID0001", "A widget cannot be added below itself.", child.mStableId);
				return;
			}
		}

		child.mParent = this;
		child.mOwner = this;
		if (index < 0 || index >= mChildren.Count)
			mChildren.Add(child);
		else
			mChildren.Insert(index, child);
		child.Invalidate(.Layout | .Style);
		child.NotifyEnabledChanged();
	}

	public Widget FindChildByStableId(StableId id)
	{
		for (let child in mChildren)
		{
			if (child.mStableId == id)
				return child;
			let nested = child.FindChildByStableId(id);
			if (nested != null)
				return nested;
		}
		return null;
	}

	public Widget mRootWidget
	{
		get
		{
			var w = this;
			while (w.mParent != null)
				w = w.mParent;
			return w;
		}
	}

	// ---- Geometry ----------------------------------------------------------------------------------------------

	// Bounds in the coordinate space of the parent (for the root: window client coordinates).
	public RectF mBounds
	{
		get
		{
			let v = mProperties.Get(WidgetTypes.sBounds);
			return RectF(v.mX, v.mY, v.mZ, v.mW);
		}
	}

	public void SetBounds(RectF bounds)
	{
		SetProperty(WidgetTypes.sBounds, Value.FromRect(bounds.mX, bounds.mY, bounds.mWidth, bounds.mHeight));
	}

	// Position of this widget's origin in root coordinates (sum of the bounds origins of all ancestors including itself).
	public PointF GetRootPosition()
	{
		float x = 0;
		float y = 0;
		for (var w = this; w != null; w = w.mParent)
		{
			let b = w.mBounds;
			x += b.mX;
			y += b.mY;
		}
		return PointF(x, y);
	}

	public RectF GetRootBounds()
	{
		let origin = GetRootPosition();
		let b = mBounds;
		return RectF(origin.mX, origin.mY, b.mWidth, b.mHeight);
	}

	public PointF RootToLocal(float rootX, float rootY)
	{
		let origin = GetRootPosition();
		return PointF(rootX - origin.mX, rootY - origin.mY);
	}

	// Point in local coordinates. Default: inside the bounds rectangle. Override for other shapes.
	public virtual bool HitTest(float localX, float localY)
	{
		let b = mBounds;
		return localX >= 0 && localY >= 0 && localX < b.mWidth && localY < b.mHeight;
	}

	public virtual bool mBlocksPointer => mProperties.Get(WidgetTypes.sHitTestVisible).AsBool(true);

	// Deepest widget under a point given in the coordinate space of this widget's PARENT. Later siblings are on top.
	// Invisible or deactivating widgets and their subtrees are skipped. Disabled widgets are still hit: they block the
	// widgets below them but do not receive input (see InputRouter).
	public Widget FindTargetAt(float parentX, float parentY)
	{
		if (!mIsAlive || !mProperties.Get(WidgetTypes.sVisible).AsBool(true))
			return null;

		let b = mBounds;
		let lx = parentX - b.mX;
		let ly = parentY - b.mY;
		for (var i = mChildren.Count - 1; i >= 0; i--)
		{
			let hit = mChildren[i].FindTargetAt(lx, ly);
			if (hit != null)
				return hit;
		}
		return (mBlocksPointer && HitTest(lx, ly)) ? this : null;
	}

	public bool mIsEffectivelyVisible
	{
		get
		{
			for (var w = this; w != null; w = w.mParent)
			{
				if (!w.mIsAlive || !w.mProperties.Get(WidgetTypes.sVisible).AsBool(true))
					return false;
			}
			return true;
		}
	}

	public bool mIsEffectivelyEnabled
	{
		get
		{
			for (var w = this; w != null; w = w.mParent)
			{
				if (!w.mProperties.Get(WidgetTypes.sEnabled).AsBool(true))
					return false;
			}
			return true;
		}
	}

	// ---- Invalidation --------------------------------------------------------------------------------------------

	public void Invalidate(Invalidation flags)
	{
		mDirty |= flags;
		for (var w = mParent; w != null && !w.bSubtreeDirty; w = w.mParent)
			w.bSubtreeDirty = true;
	}

	// IPropertyChangeListener: a property changed -> mark what depends on it.
	public virtual void OnPropertyChanged(PropertyStore store, PropertyDescriptor property, Value oldValue, Value newValue)
	{
		Invalidate(property.mInvalidates);
		if (property == WidgetTypes.sEnabled)
			NotifyEnabledChanged();
	}

	// IsEffectivelyEnabled of this widget and all descendants may have changed: tell observers (bindings, styles).
	void NotifyEnabledChanged()
	{
		mProperties.Observe(WidgetTypes.sIsEffectivelyEnabled).NotifyChanged();
		Invalidate(.Style | .Visual);
		for (let child in mChildren)
			child.NotifyEnabledChanged();
	}

	// ---- IPropertyHost -------------------------------------------------------------------------------------------

	override public Value GetProperty(PropertyDescriptor property)
	{
		if (property == WidgetTypes.sIsEffectivelyEnabled)
			return Value.FromBool(mIsEffectivelyEnabled);
		return mProperties.Get(property);
	}

	override public Result<void, PropertyError> SetProperty(PropertyDescriptor property, Value value)
	{
		if (mProperties.Set(property, value) case .Err(let error))
			return .Err(error);
		return .Ok;
	}

	override public IObservable GetObservable(PropertyDescriptor property)
	{
		return mProperties.Observe(property);
	}

	// State written by the widget runtime itself (Hovered, Pressed, Focused ...). Returns true if it changed.
	protected bool SetState(PropertyDescriptor property, Value value)
	{
		if (mProperties.SetInternal(property, value) case .Ok(let changed))
			return changed;
		return false;
	}

	// Runtime-only state setters (called by the input router, focus manager and by widget subclasses).
	public bool SetHovered(bool value) => SetState(WidgetTypes.sHovered, Value.FromBool(value));
	public bool SetPressed(bool value) => SetState(WidgetTypes.sPressed, Value.FromBool(value));

	public void SetFocusState(bool focused, bool keyboard)
	{
		SetState(WidgetTypes.sFocused, Value.FromBool(focused));
		SetState(WidgetTypes.sKeyboardFocused, Value.FromBool(focused && keyboard));
	}

	public WidgetStateFlags mStateFlags
	{
		get
		{
			var flags = WidgetStateFlags.None;
			if (mProperties.Get(WidgetTypes.sHovered).AsBool()) flags |= .Hovered;
			if (mProperties.Get(WidgetTypes.sPressed).AsBool()) flags |= .Pressed;
			if (mProperties.Get(WidgetTypes.sFocused).AsBool()) flags |= .Focused;
			if (mProperties.Get(WidgetTypes.sKeyboardFocused).AsBool()) flags |= .KeyboardFocused;
			if (!mIsEffectivelyEnabled) flags |= .Disabled;
			return flags;
		}
	}

	// ---- IMethodHost ---------------------------------------------------------------------------------------------

	// Validates the call against the descriptor (known method, argument count, argument types; missing arguments take the
	// parameter default) and dispatches to OnInvokeMethod. Int arguments are accepted for Float parameters.
	public Result<Value, CallError> Invoke(MethodDescriptor method, Span<Value> arguments)
	{
		if (GetDescriptor().FindMethod(method.mName) != method)
			return .Err(.UnknownMethod);
		if (arguments.Length > method.mParameters.Count)
			return .Err(.ArgumentCount);

		let normalized = scope List<Value>();
		for (int i < method.mParameters.Count)
		{
			let parameter = method.mParameters[i];
			var argument = (i < arguments.Length) ? arguments[i] : parameter.mDefault;
			if (i >= arguments.Length && argument.mIsNone)
				return .Err(.ArgumentCount);
			if (argument.mKind == .Int && parameter.mKind == .Float)
				argument = Value.FromFloat((double)argument.mInt);
			if (argument.mKind != parameter.mKind)
				return .Err(.ArgumentType);
			normalized.Add(argument);
		}
		return OnInvokeMethod(method, normalized);
	}

	protected virtual Result<Value, CallError> OnInvokeMethod(MethodDescriptor method, List<Value> arguments)
	{
		if (method == WidgetTypes.sFocus)
		{
			let host = mContext.mWidgetHost;
			return .Ok(Value.FromBool(host != null && host.RequestFocus(this, .Programmatic)));
		}
		if (method == WidgetTypes.sBlur)
		{
			if (mContext.mWidgetHost != null)
				mContext.mWidgetHost.ReleaseFocus(this);
			return .Ok(Value.sNone);
		}
		return .Err(.UnknownMethod);
	}

	// ---- IEventSource --------------------------------------------------------------------------------------------

	public SubscriptionId Subscribe(EventDescriptor ev, IEventListener listener)
	{
		return mEvents.Subscribe(ev, listener);
	}

	public void Unsubscribe(SubscriptionId id)
	{
		mEvents.Unsubscribe(id);
	}

	public int RaiseEvent(EventDescriptor ev, Span<Value> arguments = default)
	{
		return mEvents.Raise(this, ev, arguments);
	}

	// ---- Input hooks (called by the InputRouter in the Input phase) --------------------------------------------
	// Set e.bHandled = true to stop routing. Preview hooks run root -> target (tunnel), the others target -> root (bubble).
	// Disabled widgets receive no input callbacks. Pointer coordinates: e.mLocalX / e.mLocalY are local to this widget.

	public virtual void OnPreviewPointer(ref PointerEvent e) { }
	public virtual void OnPointerDown(ref PointerEvent e) { }
	public virtual void OnPointerUp(ref PointerEvent e) { }
	public virtual void OnPointerMove(ref PointerEvent e) { }
	public virtual void OnPointerWheel(ref PointerEvent e) { }
	public virtual void OnPointerCancel() { }                       // the platform took the pointer away
	public virtual void OnPointerEntered() { RaiseEvent(WidgetTypes.sPointerEntered); }
	public virtual void OnPointerExited() { RaiseEvent(WidgetTypes.sPointerExited); }

	public virtual void OnPreviewKey(ref KeyEvent e) { }
	public virtual void OnKeyDown(ref KeyEvent e) { }
	public virtual void OnKeyUp(ref KeyEvent e) { }
	public virtual void OnTextInput(ref TextInputEvent e) { }

	public virtual void OnFocusGained(FocusReason reason) { RaiseEvent(WidgetTypes.sFocusGained); }
	public virtual void OnFocusLost() { RaiseEvent(WidgetTypes.sFocusLost); }

	// Cursor shown while the pointer is over this widget (Default = what the widget type prefers).
	public virtual CursorKind GetDefaultCursor() => .Arrow;

	public CursorKind mEffectiveCursor
	{
		get
		{
			let name = mProperties.Get(WidgetTypes.sCursor).AsString();
			if (name.IsEmpty || name == "Default")
				return GetDefaultCursor();
			if (Enum.Parse<CursorKind>(name) case .Ok(let kind))
				return (kind == .Default) ? GetDefaultCursor() : kind;
			return GetDefaultCursor();
		}
	}
}
