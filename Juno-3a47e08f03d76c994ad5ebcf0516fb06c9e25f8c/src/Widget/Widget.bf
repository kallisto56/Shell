namespace Juno;

using System;
using System.Collections;

// Base class of the UI. A widget has a rectangle in the coordinate space of its parent (mX, mY, mWidth, mHeight)
// and draws / receives input in its own local space (0,0 = its top-left corner).
//
//   - Children are owned (deleted with the parent). Use AddChild / RemoveChild / Close.
//   - Input is routed by WidgetRoot: hover, mouse capture while a button is held, keyboard focus, bubbling to parents.
//   - Override the On* methods in subclasses, or hook the Event fields (mOnClick ...) for ad-hoc handlers.
class Widget
{
	public String mName = new .() ~ delete _;
	public Widget mParent;
	public WidgetRoot mRoot;
	public List<Widget> mChildren = new .() ~ DeleteContainerAndItems!(_);

	public float mX;
	public float mY;
	public float mWidth;
	public float mHeight;
	public Anchor mAnchor = .Left | .Top;

	public bool bVisible = true;
	public bool bEnabled = true;
	public bool bHitTestVisible = true;     // false: mouse input passes through this widget (children still work)
	public bool bClipChildren = false;
	public bool bFocusable = false;

	public bool bMouseOver;
	public bool bPressed;
	public bool bHasFocus;

	public Event<delegate void(Widget)> mOnClick ~ _.Dispose();
	public Event<delegate void(Widget, MouseEventArgs)> mOnMouseDown ~ _.Dispose();
	public Event<delegate void(Widget, MouseEventArgs)> mOnMouseUp ~ _.Dispose();
	public Event<delegate void(Widget, KeyEventArgs)> mOnKeyDown ~ _.Dispose();

	public this()
	{
	}

	public this(float x, float y, float width, float height)
	{
		this.mX = x;
		this.mY = y;
		this.mWidth = width;
		this.mHeight = height;
	}

	public ~this()
	{
		if (this.mRoot != null)
			this.mRoot.OnWidgetRemoved(this);
	}

	// ---------------------------------------------------------------------------------------------------------
	// Hierarchy
	// ---------------------------------------------------------------------------------------------------------

	public T AddChild<T>(T child) where T : Widget
	{
		Runtime.Assert(child.mParent == null, "Widget already has a parent");
		child.mParent = this;
		child.AttachRoot(this.mRoot);
		this.mChildren.Add(child);
		child.OnAdded();
		return child;
	}

	// Detaches the child without deleting it.
	public void RemoveChild(Widget child)
	{
		if (this.mChildren.Remove(child))
		{
			if (this.mRoot != null)
				this.mRoot.OnWidgetRemoved(child);
			child.mParent = null;
			child.AttachRoot(null);
		}
	}

	// Removes this widget from its parent and deletes it. Do not use the widget afterwards.
	public void Close()
	{
		if (this.mParent != null)
			this.mParent.RemoveChild(this);
		delete this;
	}

	void AttachRoot(WidgetRoot root)
	{
		this.mRoot = root;
		for (let child in this.mChildren)
			child.AttachRoot(root);
	}

	// ---------------------------------------------------------------------------------------------------------
	// Geometry
	// ---------------------------------------------------------------------------------------------------------

	public Rect mBounds => Rect(this.mX, this.mY, this.mWidth, this.mHeight);
	public Rect mLocalRect => Rect(0, 0, this.mWidth, this.mHeight);

	public void SetBounds(float x, float y, float width, float height)
	{
		this.mX = x;
		this.mY = y;
		this.Resize(width, height);
	}

	public void Resize(float width, float height)
	{
		let oldWidth = this.mWidth;
		let oldHeight = this.mHeight;
		this.mWidth = width;
		this.mHeight = height;
		if (oldWidth != width || oldHeight != height)
		{
			this.ApplyChildAnchors(oldWidth, oldHeight);
			this.OnResized(oldWidth, oldHeight);
		}
	}

	void ApplyChildAnchors(float oldWidth, float oldHeight)
	{
		let dx = this.mWidth - oldWidth;
		let dy = this.mHeight - oldHeight;
		for (let child in this.mChildren)
		{
			let anchor = child.mAnchor;
			var x = child.mX;
			var y = child.mY;
			var w = child.mWidth;
			var h = child.mHeight;

			let bLeft = (anchor & .Left) != 0;
			let bRight = (anchor & .Right) != 0;
			let bTop = (anchor & .Top) != 0;
			let bBottom = (anchor & .Bottom) != 0;

			if (bRight && !bLeft) x += dx;
			else if (bRight && bLeft) w += dx;
			else if (!bRight && !bLeft) x += dx * 0.5f;

			if (bBottom && !bTop) y += dy;
			else if (bBottom && bTop) h += dy;
			else if (!bBottom && !bTop) y += dy * 0.5f;

			child.SetBounds(x, y, w, h);
		}
	}

	// Position of this widget's origin in root space.
	public Vector2 GetRootPosition()
	{
		float x = 0;
		float y = 0;
		Widget w = this;
		while (w != null && w.mParent != null)
		{
			x += w.mX;
			y += w.mY;
			w = w.mParent;
		}
		return Vector2(x, y);
	}

	public Vector2 RootToLocal(float rootX, float rootY)
	{
		let origin = this.GetRootPosition();
		return Vector2(rootX - origin.mX, rootY - origin.mY);
	}

	public Vector2 LocalToRoot(float localX, float localY)
	{
		let origin = this.GetRootPosition();
		return Vector2(localX + origin.mX, localY + origin.mY);
	}

	// x, y in local space.
	public virtual bool HitTest(float x, float y)
	{
		return this.bHitTestVisible && x >= 0 && y >= 0 && x < this.mWidth && y < this.mHeight;
	}

	// Topmost visible widget under (x, y) given in local space; null if nothing is hit.
	public Widget FindWidgetAt(float x, float y)
	{
		if (!this.bVisible || !this.bEnabled)
			return null;
		if (this.bClipChildren && !(x >= 0 && y >= 0 && x < this.mWidth && y < this.mHeight))
			return null;

		for (var i = this.mChildren.Count - 1; i >= 0; i--)
		{
			let child = this.mChildren[i];
			let hit = child.FindWidgetAt(x - child.mX, y - child.mY);
			if (hit != null)
				return hit;
		}
		return this.HitTest(x, y) ? this : null;
	}

	// ---------------------------------------------------------------------------------------------------------
	// Update / draw
	// ---------------------------------------------------------------------------------------------------------

	public void UpdateAll(float deltaTime)
	{
		if (!this.bVisible)
			return;
		this.OnUpdate(deltaTime);
		for (let child in this.mChildren)
			child.UpdateAll(deltaTime);
	}

	public void DrawAll(Graphics g)
	{
		if (!this.bVisible)
			return;

		g.PushTranslate(this.mX, this.mY);
		this.OnDraw(g);
		if (this.bClipChildren)
			g.PushClip(this.mLocalRect);
		for (let child in this.mChildren)
			child.DrawAll(g);
		if (this.bClipChildren)
			g.PopClip();
		g.PopTransform();
	}

	// ---------------------------------------------------------------------------------------------------------
	// Virtuals
	// ---------------------------------------------------------------------------------------------------------

	public virtual void OnAdded() { }
	public virtual void OnResized(float oldWidth, float oldHeight) { }
	public virtual void OnUpdate(float deltaTime) { }
	public virtual void OnDraw(Graphics g) { }

	public virtual void OnMouseEnter() { }
	public virtual void OnMouseLeave() { }
	public virtual void OnMouseMove(MouseEventArgs args) { }
	public virtual void OnMouseDown(ref MouseEventArgs args) { }       // set args.bHandled to stop bubbling
	public virtual void OnMouseUp(ref MouseEventArgs args) { }
	public virtual void OnMouseWheel(ref MouseEventArgs args) { }
	public virtual void OnClick(MouseEventArgs args) { }

	public virtual void OnKeyDown(ref KeyEventArgs args) { }
	public virtual void OnKeyUp(ref KeyEventArgs args) { }
	public virtual void OnTextInput(char32 c) { }
	public virtual void OnGotFocus() { }
	public virtual void OnLostFocus() { }
}
