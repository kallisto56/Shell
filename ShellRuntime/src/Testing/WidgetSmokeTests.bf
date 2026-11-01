namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Widgets;
using Shell.Input;
using Shell.Text;
using Shell.Platform;

// Headless checks of the widget runtime: no window, no GPU, no platform services. Drives the real kernel with scripted input and
// verifies pointer routing, focus and keyboard navigation, Button behavior, TextBox editing (clusters, selection, IME composition),
// property / method validation. Call WidgetSmokeTests.Run(sink) from any host; failures are reported as errors with code TEST.
static class WidgetSmokeTests
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
		public ContainerWidget mRoot;

		public this()
		{
			mContext = new RuntimeContext();
			mKernel = new ShellKernel(mContext);
			mWidgets = new WidgetRuntime(mKernel);
			mRoot = mWidgets.CreateRoot(400, 300);
		}

		public ~this()
		{
			mWidgets.Shutdown();
			delete mWidgets;
			delete mKernel;
			delete mContext;
		}

		public void Tick() => mKernel.Tick(0.016);

		void Pointer(PointerEventKind kind, float x, float y, PointerButton button, int32 clicks = 1, KeyModifiers mods = .None)
		{
			PointerEvent e = default;
			e.mKind = kind;
			e.mX = x;
			e.mY = y;
			e.mButton = button;
			e.mClickCount = clicks;
			e.mModifiers = mods;
			mWidgets.mInput.EnqueuePointer(e);
		}

		public void Move(float x, float y) { Pointer(.Move, x, y, .None, 0); Tick(); }
		public void Down(float x, float y, int32 clicks = 1) { Pointer(.Down, x, y, .Left, clicks); Tick(); }
		public void Up(float x, float y) { Pointer(.Up, x, y, .Left, 0); Tick(); }
		public void Click(float x, float y) { Move(x, y); Down(x, y); Up(x, y); }

		public void Key(Key key, bool down = true, KeyModifiers mods = .None)
		{
			KeyEvent e = default;
			e.mKey = key;
			e.bIsDown = down;
			e.mModifiers = mods;
			mWidgets.mInput.EnqueueKey(e);
			Tick();
		}

		public void Tap(Key key, KeyModifiers mods = .None)
		{
			Key(key, true, mods);
			Key(key, false, mods);
		}

		public void Text(StringView text)
		{
			mWidgets.mInput.EnqueueText(text);
			Tick();
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

	static StringView TextOf(TextBox box) => box.GetProperty(TextBox.sText).AsString();

	static public int Run(DiagnosticSink sink)
	{
		int failures = 0;
		TestButtonPointer(sink, ref failures);
		TestDisabledButton(sink, ref failures);
		TestKeyboardNavigation(sink, ref failures);
		TestTextBoxEditing(sink, ref failures);
		TestTextBoxIme(sink, ref failures);
		TestReflection(sink, ref failures);
		return failures;
	}

	static void TestButtonPointer(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness();
		let button = h.mWidgets.Create<Button>(h.mRoot, RectF(10, 10, 100, 30));
		let clicks = scope Counter();
		button.Subscribe(Button.sClicked, clicks);

		h.Move(20, 20);
		Check(button.GetProperty(WidgetTypes.sHovered).AsBool(), "button is hovered after the pointer moved onto it", sink, ref failures);
		h.Down(20, 20);
		Check(button.GetProperty(WidgetTypes.sPressed).AsBool(), "button is pressed while the pointer is down", sink, ref failures);
		Check(button.GetProperty(WidgetTypes.sFocused).AsBool(), "pressing a button focuses it", sink, ref failures);
		h.Up(20, 20);
		Check(clicks.mCount == 1, "release inside raises Clicked once", sink, ref failures);
		Check(!button.GetProperty(WidgetTypes.sPressed).AsBool(), "button is not pressed after release", sink, ref failures);

		// Press, drag away, release outside: no click.
		h.Down(20, 20);
		h.Move(300, 200);
		Check(!button.GetProperty(WidgetTypes.sPressed).AsBool(), "pressed state follows the pointer leaving the button", sink, ref failures);
		h.Up(300, 200);
		Check(clicks.mCount == 1, "release outside does not click", sink, ref failures);
		Check(!button.GetProperty(WidgetTypes.sHovered).AsBool(), "button is not hovered after the pointer left", sink, ref failures);
	}

	static void TestDisabledButton(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness();
		let button = h.mWidgets.Create<Button>(h.mRoot, RectF(10, 10, 100, 30));
		let clicks = scope Counter();
		button.Subscribe(Button.sClicked, clicks);

		button.SetProperty(WidgetTypes.sEnabled, Value.FromBool(false));
		h.Click(20, 20);
		Check(clicks.mCount == 0, "a disabled button does not click", sink, ref failures);
		Check(!button.GetProperty(WidgetTypes.sFocused).AsBool(), "a disabled button cannot take focus", sink, ref failures);
		Check(!button.GetProperty(WidgetTypes.sIsEffectivelyEnabled).AsBool(), "IsEffectivelyEnabled is false", sink, ref failures);
	}

	static void TestKeyboardNavigation(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness();
		let first = h.mWidgets.Create<Button>(h.mRoot, RectF(10, 10, 100, 30));
		let second = h.mWidgets.Create<Button>(h.mRoot, RectF(10, 60, 100, 30));
		let clicks = scope Counter();
		second.Subscribe(Button.sClicked, clicks);

		h.Tap(.Tab);
		Check(first.GetProperty(WidgetTypes.sKeyboardFocused).AsBool(), "Tab focuses the first focusable widget with the keyboard ring", sink, ref failures);
		h.Tap(.Tab);
		Check(second.GetProperty(WidgetTypes.sFocused).AsBool() && !first.GetProperty(WidgetTypes.sFocused).AsBool(), "Tab moves focus to the next widget", sink, ref failures);
		h.Tap(.Tab, .Shift);
		Check(first.GetProperty(WidgetTypes.sFocused).AsBool(), "Shift+Tab moves focus back", sink, ref failures);
		h.Tap(.Down);
		Check(second.GetProperty(WidgetTypes.sFocused).AsBool(), "Down moves focus spatially", sink, ref failures);
		h.Key(.Space, true);
		h.Key(.Space, false);
		Check(clicks.mCount == 1, "Space on the focused button clicks it", sink, ref failures);
	}

	static void TestTextBoxEditing(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness();
		let box = h.mWidgets.Create<TextBox>(h.mRoot, RectF(20, 50, 200, 24));

		h.Click(30, 60);
		Check(box.GetProperty(WidgetTypes.sFocused).AsBool(), "clicking a text box focuses it", sink, ref failures);

		h.Text("h\u{E9}llo");
		Check(TextOf(box) == "h\u{E9}llo", "typed text appears in Text", sink, ref failures);
		Check(box.GetProperty(TextBox.sTextLength).AsInt() == 5, "TextLength counts UTF-16 units", sink, ref failures);

		h.Tap(.Backspace);
		Check(TextOf(box) == "h\u{E9}ll", "Backspace removes the last character", sink, ref failures);

		h.Tap(.Left, .Shift);
		h.Tap(.Left, .Shift);
		Check(box.GetProperty(TextBox.sSelectionLength).AsInt() == 2 && box.GetProperty(TextBox.sHasSelection).AsBool(), "Shift+Left twice selects two characters", sink, ref failures);
		h.Text("X");
		Check(TextOf(box) == "h\u{E9}X", "typing replaces the selection", sink, ref failures);

		h.Tap(.A, .Control);
		Check(box.GetProperty(TextBox.sSelectionLength).AsInt() == 3, "Ctrl+A selects everything", sink, ref failures);
		h.Text("e\u{301}");
		Check(TextOf(box) == "e\u{301}", "combining sequence is inserted as typed", sink, ref failures);
		h.Tap(.Backspace);
		Check(TextOf(box).IsEmpty, "Backspace deletes a whole grapheme cluster (base + combining mark)", sink, ref failures);

		h.Text("abc def");
		h.Tap(.Left, .Control);
		Check(box.GetProperty(TextBox.sCaretIndex).AsInt() == 4, "Ctrl+Left moves to the start of the word", sink, ref failures);
	}

	static void TestTextBoxIme(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness();
		let box = h.mWidgets.Create<TextBox>(h.mRoot, RectF(20, 50, 200, 24));
		h.Click(30, 60);
		h.Text("ab");

		let client = (ITextInputClient)box;
		client.SetComposition("\u{306B}\u{307B}\u{3093}", 3);
		Check(box.GetProperty(TextBox.sIsComposing).AsBool(), "IsComposing is true during composition", sink, ref failures);
		Check(TextOf(box) == "ab", "composition text is not part of Text", sink, ref failures);

		client.GetSelection(var start, var end);
		client.SetComposition("", 0);
		client.ReplaceText(start, end, "\u{65E5}\u{672C}");
		Check(TextOf(box) == "ab\u{65E5}\u{672C}", "committed IME text is inserted at the caret", sink, ref failures);
		Check(!box.GetProperty(TextBox.sIsComposing).AsBool(), "composition ended after the commit", sink, ref failures);
	}

	static void TestReflection(DiagnosticSink sink, ref int failures)
	{
		let h = scope Harness();
		let box = h.mWidgets.Create<TextBox>(h.mRoot, RectF(20, 50, 200, 24));

		let one = scope List<Value>();
		one.Add(Value.FromInt(1));
		Check(box.Invoke(TextBox.sSelect, one) case .Err(.ArgumentCount), "calling Select with a missing argument fails with ArgumentCount", sink, ref failures);

		let wrong = scope List<Value>();
		wrong.Add(Value.FromString("x"));
		wrong.Add(Value.FromInt(1));
		Check(box.Invoke(TextBox.sSelect, wrong) case .Err(.ArgumentType), "calling Select with a string fails with ArgumentType", sink, ref failures);

		let text = h.mContext.mStrings.InternTransient("abc");
		box.SetProperty(TextBox.sText, Value.FromString(text));
		Check(box.GetProperty(TextBox.sTextLength).AsInt() == 3, "setting Text from outside updates the computed TextLength", sink, ref failures);

		Check(box.SetProperty(WidgetTypes.sHovered, Value.FromBool(true)) case .Err(.ReadOnly), "State properties cannot be written from outside", sink, ref failures);
		Check(box.SetProperty(TextBox.sTextLength, Value.FromInt(7)) case .Err(.ReadOnly), "Computed properties cannot be written", sink, ref failures);
	}
}
