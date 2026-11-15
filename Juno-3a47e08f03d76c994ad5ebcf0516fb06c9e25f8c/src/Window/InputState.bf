namespace Juno;

using System;
using System.Collections;

// Polled keyboard / mouse state. Fed by ApplicationWindow, cleared by Application at the end of each frame.
//   IsKeyDown      - held right now
//   WasKeyPressed  - went down this frame (no auto-repeat)
//   WasKeyReleased - went up this frame
//   WasKeyTyped    - pressed this frame OR auto-repeated (use for text-editing style navigation)
class InputState
{
	const double cDoubleClickTime = 0.4;
	const float cDoubleClickDistance = 4.0f;

	bool[256] mKeyDown;
	bool[256] mKeyPressed;
	bool[256] mKeyReleased;
	bool[256] mKeyRepeated;

	bool[5] mButtonDown;
	bool[5] mButtonPressed;
	bool[5] mButtonReleased;
	int32[5] mClickCount;
	double[5] mLastClickTime;
	Vector2 mLastClickPosition;

	public Vector2 mMousePosition;
	public Vector2 mMouseDelta;
	public Vector2 mMouseWheel;         // x = horizontal, y = vertical, in notches
	public bool bMouseKnown;            // False until the first mouse message arrived.
	public String mTextInput = new .() ~ delete _;   // UTF-8 text typed this frame

	public bool IsKeyDown(KeyCode key) => (int32)key >= 0 && (int32)key < 256 && mKeyDown[(int)key];
	public bool WasKeyPressed(KeyCode key) => (int32)key >= 0 && (int32)key < 256 && mKeyPressed[(int)key];
	public bool WasKeyReleased(KeyCode key) => (int32)key >= 0 && (int32)key < 256 && mKeyReleased[(int)key];
	public bool WasKeyTyped(KeyCode key) => (int32)key >= 0 && (int32)key < 256 && (mKeyPressed[(int)key] || mKeyRepeated[(int)key]);

	public bool IsMouseDown(MouseButton button) => mButtonDown[(int)button];
	public bool WasMousePressed(MouseButton button) => mButtonPressed[(int)button];
	public bool WasMouseReleased(MouseButton button) => mButtonReleased[(int)button];

	public KeyModifiers mModifiers
	{
		get
		{
			KeyModifiers result = .None;
			if (mKeyDown[(int)KeyCode.Shift]) result |= .Shift;
			if (mKeyDown[(int)KeyCode.Control]) result |= .Control;
			if (mKeyDown[(int)KeyCode.Alt]) result |= .Alt;
			if (mKeyDown[(int)KeyCode.LWin] || mKeyDown[(int)KeyCode.RWin]) result |= .Super;
			return result;
		}
	}

	// ---- Feeding (called by the window) -----------------------------------------------------------------------

	public void NotifyKeyDown(KeyCode key, bool isRepeat)
	{
		if ((int32)key <= 0 || (int32)key >= 256)
			return;

		let idx = (int)key;
		if (!mKeyDown[idx])
			mKeyPressed[idx] = true;
		if (isRepeat)
			mKeyRepeated[idx] = true;
		mKeyDown[idx] = true;
		RefreshGenericModifiers();
	}

	public void NotifyKeyUp(KeyCode key)
	{
		if ((int32)key <= 0 || (int32)key >= 256)
			return;

		let idx = (int)key;
		if (mKeyDown[idx])
			mKeyReleased[idx] = true;
		mKeyDown[idx] = false;
		RefreshGenericModifiers();
	}

	// The generic Shift/Control/Alt codes mirror their left/right variants.
	void RefreshGenericModifiers()
	{
		mKeyDown[(int)KeyCode.Shift] = mKeyDown[(int)KeyCode.LShift] || mKeyDown[(int)KeyCode.RShift];
		mKeyDown[(int)KeyCode.Control] = mKeyDown[(int)KeyCode.LControl] || mKeyDown[(int)KeyCode.RControl];
		mKeyDown[(int)KeyCode.Alt] = mKeyDown[(int)KeyCode.LAlt] || mKeyDown[(int)KeyCode.RAlt];
	}

	public void NotifyText(char32 c)
	{
		mTextInput.Append(c);
	}

	public void NotifyMouseMove(float x, float y)
	{
		if (bMouseKnown)
		{
			mMouseDelta.mX += x - mMousePosition.mX;
			mMouseDelta.mY += y - mMousePosition.mY;
		}
		bMouseKnown = true;
		mMousePosition = Vector2(x, y);
	}

	// Returns the click count (1, 2, 3...) for presses, 0 for releases.
	public int32 NotifyMouseButton(MouseButton button, bool down, double time)
	{
		let idx = (int)button;
		if (!down)
		{
			if (mButtonDown[idx])
				mButtonReleased[idx] = true;
			mButtonDown[idx] = false;
			return 0;
		}

		let dx = mMousePosition.mX - mLastClickPosition.mX;
		let dy = mMousePosition.mY - mLastClickPosition.mY;
		if (time - mLastClickTime[idx] <= cDoubleClickTime && (dx * dx + dy * dy) <= cDoubleClickDistance * cDoubleClickDistance)
			mClickCount[idx]++;
		else
			mClickCount[idx] = 1;

		mLastClickTime[idx] = time;
		mLastClickPosition = mMousePosition;
		mButtonPressed[idx] = true;
		mButtonDown[idx] = true;
		return mClickCount[idx];
	}

	public void NotifyWheel(float dx, float dy)
	{
		mMouseWheel.mX += dx;
		mMouseWheel.mY += dy;
	}

	// Window lost focus: pretend everything was released so nothing stays "stuck".
	public void ReleaseAll()
	{
		for (int i < 256)
		{
			if (mKeyDown[i])
				mKeyReleased[i] = true;
			mKeyDown[i] = false;
		}
		for (int i < 5)
		{
			if (mButtonDown[i])
				mButtonReleased[i] = true;
			mButtonDown[i] = false;
		}
	}

	// Clears per-frame data. Called by Application after Update/Draw.
	public void EndFrame()
	{
		for (int i < 256)
		{
			mKeyPressed[i] = false;
			mKeyReleased[i] = false;
			mKeyRepeated[i] = false;
		}
		for (int i < 5)
		{
			mButtonPressed[i] = false;
			mButtonReleased[i] = false;
		}
		mMouseDelta = Vector2(0, 0);
		mMouseWheel = Vector2(0, 0);
		mTextInput.Clear();
	}
}
