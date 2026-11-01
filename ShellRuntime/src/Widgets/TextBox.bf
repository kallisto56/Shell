namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Widgets;
using Shell.Input;
using Shell.Text;
using Shell.Platform;

// Text editing control.
//
// Public model (what bindings, Blueprints and the editor see)
//   Text, PlaceholderText, IsReadOnly, AcceptsReturn (multi-line), AcceptsTab, MaxLength (code points, 0 = unlimited)   writable values
//   SelectionStart, SelectionLength, CaretIndex                                         writable values, UTF-16 code unit offsets
//   CaretRect, IsComposing, CompositionText                                              read-only state (CaretRect is local to the widget)
//   HasSelection, SelectedText, TextLength                                               computed (SelectedText is valid for the current frame)
//   events TextChanged(Text), SelectionChanged(Start, Length), Submitted(Text); methods SelectAll, Select, Clear, InsertText,
//   Cut, Copy, Paste, SetCaret
//
// Internals use UTF-8 byte offsets; caret movement and deletion work on grapheme clusters (ITextSegmenter), selections never
// split a cluster. Geometry (mouse hit testing, caret rectangle, visual left/right in bidirectional text) comes from ITextMetrics,
// supplied by the Text element once it exists; until then FallbackTextMetrics (fixed advance) is used.
// IME: the widget is an ITextInputClient. Composition text is kept apart from Text (shown by the skin through CompositionText)
// and is inserted when the IME commits it.
class TextBox : Widget, ITextInputClient
{
	static public TypeDescriptor sType;
	static public PropertyDescriptor sText;
	static public PropertyDescriptor sPlaceholder;
	static public PropertyDescriptor sReadOnly;
	static public PropertyDescriptor sAcceptsReturn;
	static public PropertyDescriptor sAcceptsTab;
	static public PropertyDescriptor sMaxLength;
	static public PropertyDescriptor sSelectionStart;
	static public PropertyDescriptor sSelectionLength;
	static public PropertyDescriptor sCaretIndex;
	static public PropertyDescriptor sCaretRect;
	static public PropertyDescriptor sIsComposing;
	static public PropertyDescriptor sCompositionText;
	static public PropertyDescriptor sHasSelection;
	static public PropertyDescriptor sSelectedText;
	static public PropertyDescriptor sTextLength;
	static public EventDescriptor sTextChanged;
	static public EventDescriptor sSelectionChanged;
	static public EventDescriptor sSubmitted;
	static public MethodDescriptor sSelectAll;
	static public MethodDescriptor sSelect;
	static public MethodDescriptor sClear;
	static public MethodDescriptor sInsertText;
	static public MethodDescriptor sCut;
	static public MethodDescriptor sCopy;
	static public MethodDescriptor sPaste;
	static public MethodDescriptor sSetCaret;

	String mText = new .() ~ delete _;
	String mComposition = new .() ~ delete _;
	ITextSegmenter mSegmenter = new SimpleTextSegmenter() ~ delete _;
	FallbackTextMetrics mFallbackMetrics ~ delete _;
	public ITextMetrics mMetrics;               // set by the Text element; null = fallback metrics

	int mCaret;                                 // byte offsets
	int mAnchor;
	int mCompositionStart;
	int mCompositionCursor;                     // UTF-16 offset inside the composition text
	bool bComposing;
	bool bUpdating;                             // true while the widget writes its own properties
	bool bDragging;
	float mDesiredX = -1;
	int mPublishedStart = -1;
	int mPublishedLength = -1;
	int mPublishedCaret = -1;

	static public bool Register(RuntimeContext context)
	{
		if (sType == null)
		{
			let b = new WidgetTypeBuilder("TextBox", WidgetTypes.sWidget);
			sText = b.AddValue("Text", .String, default, .Layout | .Text | .Visual);
			sPlaceholder = b.AddValue("PlaceholderText", .String, default, .Visual);
			sReadOnly = b.AddValue("IsReadOnly", .Bool, Value.FromBool(false), .Style | .Visual);
			sAcceptsReturn = b.AddValue("AcceptsReturn", .Bool, Value.FromBool(false), .Layout);
			sAcceptsTab = b.AddValue("AcceptsTab", .Bool, Value.FromBool(false), .None);
			sMaxLength = b.AddValue("MaxLength", .Int, Value.FromInt(0), .None);
			sSelectionStart = b.AddValue("SelectionStart", .Int, Value.FromInt(0), .Visual, .Bindable);
			sSelectionLength = b.AddValue("SelectionLength", .Int, Value.FromInt(0), .Visual, .Bindable);
			sCaretIndex = b.AddValue("CaretIndex", .Int, Value.FromInt(0), .Visual, .Bindable);
			sCaretRect = b.AddState("CaretRect", .Rect, default, .Visual);
			sIsComposing = b.AddState("IsComposing", .Bool, Value.FromBool(false), .Style | .Visual);
			sCompositionText = b.AddState("CompositionText", .String, default, .Text | .Visual);
			sHasSelection = b.AddComputed("HasSelection", .Bool);
			sSelectedText = b.AddComputed("SelectedText", .String);
			sTextLength = b.AddComputed("TextLength", .Int);
			sTextChanged = b.AddEvent("TextChanged").Param("Text", .String);
			sSelectionChanged = b.AddEvent("SelectionChanged").Param("Start", .Int).Param("Length", .Int);
			sSubmitted = b.AddEvent("Submitted").Param("Text", .String);
			sSelectAll = b.AddMethod("SelectAll");
			sSelect = b.AddMethod("Select").Param("Start", .Int).Param("Length", .Int);
			sClear = b.AddMethod("Clear");
			sInsertText = b.AddMethod("InsertText").Param("Text", .String);
			sCut = b.AddMethod("Cut");
			sCopy = b.AddMethod("Copy");
			sPaste = b.AddMethod("Paste");
			sSetCaret = b.AddMethod("SetCaret").Param("Index", .Int);
			sType = b.mType;
			sType.OverrideDefault(WidgetTypes.sFocusable, Value.FromBool(true));
			delete b;
		}
		return context.mTypes.Register(sType, context.mDiagnostics, false);
	}

	public override TypeDescriptor GetDescriptor() => sType;
	public override CursorKind GetDefaultCursor() => .IBeam;

	// ---- Basic accessors ---------------------------------------------------------------------------------------------

	public StringView mTextView => mText;
	ITextMetrics Metrics => (mMetrics != null) ? mMetrics : (ITextMetrics)mFallbackMetrics;
	bool mIsReadOnly => mProperties.Get(sReadOnly).AsBool();
	bool mIsMultiline => mProperties.Get(sAcceptsReturn).AsBool();
	int mSelStart => Math.Min(mCaret, mAnchor);
	int mSelEnd => Math.Max(mCaret, mAnchor);
	bool mHasSel => mCaret != mAnchor;

	protected override void OnInitialize()
	{
		base.OnInitialize();
		mFallbackMetrics = new FallbackTextMetrics(this, mSegmenter);
		PublishSelection();
	}

	// ---- Properties --------------------------------------------------------------------------------------------------

	public override Value GetProperty(PropertyDescriptor property)
	{
		if (property == sHasSelection)
			return Value.FromBool(mHasSel);
		if (property == sTextLength)
			return Value.FromInt(Utf8.Utf16Length(mText));
		if (property == sSelectedText)
			return Value.FromString(mContext.mStrings.InternTransient(StringView(mText, mSelStart, mSelEnd - mSelStart)));
		return base.GetProperty(property);
	}

	void NotifyComputed()
	{
		mProperties.Observe(sHasSelection).NotifyChanged();
		mProperties.Observe(sSelectedText).NotifyChanged();
		mProperties.Observe(sTextLength).NotifyChanged();
	}

	void WriteInternal(PropertyDescriptor property, Value value)
	{
		bUpdating = true;
		mProperties.SetInternal(property, value);
		bUpdating = false;
	}

	public override void OnPropertyChanged(PropertyStore store, PropertyDescriptor property, Value oldValue, Value newValue)
	{
		base.OnPropertyChanged(store, property, oldValue, newValue);
		if (bUpdating)
			return;

		if (property == sText)
		{
			// Set from outside (binding, Blueprint, editor): adopt it, keep the caret inside, drop any composition.
			CancelComposition();
			mText.Set(newValue.mString);
			mCaret = SnapToCluster(Math.Min(mCaret, mText.Length));
			mAnchor = SnapToCluster(Math.Min(mAnchor, mText.Length));
			NotifyComputed();
			PublishSelection();
			RaiseTextChanged();
		}
		else if (property == sSelectionStart || property == sSelectionLength)
		{
			let start = Utf8.FromUtf16(mText, (int)mProperties.Get(sSelectionStart).AsInt());
			let end = Utf8.FromUtf16(mText, (int)(mProperties.Get(sSelectionStart).AsInt() + Math.Max(mProperties.Get(sSelectionLength).AsInt(), 0)));
			mAnchor = SnapToCluster(start);
			mCaret = SnapToCluster(end);
			PublishSelection();
		}
		else if (property == sCaretIndex)
		{
			mCaret = SnapToCluster(Utf8.FromUtf16(mText, (int)newValue.AsInt()));
			mAnchor = mCaret;
			PublishSelection();
		}
	}

	// A byte offset must never fall inside a grapheme cluster.
	int SnapToCluster(int index)
	{
		if (index <= 0) return 0;
		if (index >= mText.Length) return mText.Length;
		let previous = mSegmenter.PreviousCluster(mText, index);
		return (mSegmenter.NextCluster(mText, previous) == index) ? index : previous;
	}

	void PublishText()
	{
		WriteInternal(sText, Value.FromString(mContext.mStrings.InternTransient(mText)));
		NotifyComputed();
		RaiseTextChanged();
	}

	void RaiseTextChanged()
	{
		let args = scope List<Value>();
		args.Add(Value.FromString(mContext.mStrings.InternTransient(mText)));
		RaiseEvent(sTextChanged, args);
	}

	// Writes SelectionStart / SelectionLength / CaretIndex / CaretRect and raises SelectionChanged when the selection moved.
	void PublishSelection()
	{
		let start = Utf8.ToUtf16(mText, mSelStart);
		let length = Utf8.ToUtf16(mText, mSelEnd) - start;
		let caret = Utf8.ToUtf16(mText, mCaret);

		WriteInternal(sSelectionStart, Value.FromInt(start));
		WriteInternal(sSelectionLength, Value.FromInt(length));
		WriteInternal(sCaretIndex, Value.FromInt(caret));

		let bChanged = (start != mPublishedStart || length != mPublishedLength || caret != mPublishedCaret);
		mPublishedStart = start;
		mPublishedLength = length;
		mPublishedCaret = caret;

		UpdateCaretRect();
		if (bChanged)
		{
			NotifyComputed();
			let args = scope List<Value>();
			args.Add(Value.FromInt(start));
			args.Add(Value.FromInt(length));
			RaiseEvent(sSelectionChanged, args);
		}
	}

	void UpdateCaretRect()
	{
		let r = Metrics.GetCaretRect(mCaret);
		SetState(sCaretRect, Value.FromRect(r.mX, r.mY, r.mWidth, r.mHeight));
		let host = mContext.mWidgetHost;
		if (host != null && host.HasFocus(this) && host.GetTextInput() != null)
			host.GetTextInput().NotifyCaretMoved();
	}

	// ---- Editing -----------------------------------------------------------------------------------------------------

	// Normalizes line ends and removes characters a text box must not hold.
	void Sanitize(StringView input, String output)
	{
		let bMultiline = mIsMultiline;
		let bTabs = mProperties.Get(sAcceptsTab).AsBool();
		var i = 0;
		while (i < input.Length)
		{
			let cp = (char32)Utf8.Decode(input, i, var length);
			if (cp == '\r')
			{
				if (i + 1 < input.Length && input[i + 1] == '\n')
					i++;
				if (bMultiline) output.Append('\n');
			}
			else if (cp == '\n')
			{
				if (bMultiline) output.Append('\n');
			}
			else if (cp == '\t')
			{
				if (bTabs) output.Append('\t');
			}
			else if ((uint32)cp >= 0x20 && (uint32)cp != 0x7F)
			{
				output.Append(input, i, length);
			}
			i += length;
		}
	}

	// Replaces [start, end) with text; the caret ends up after the inserted text. Returns false if nothing changed.
	bool ReplaceRange(int startByte, int endByte, StringView insert)
	{
		let start = Math.Min(startByte, endByte);
		let end = Math.Max(startByte, endByte);
		let clean = scope String();
		Sanitize(insert, clean);

		let maxLength = (int)mProperties.Get(sMaxLength).AsInt();
		if (maxLength > 0)
		{
			let current = Utf8.CodePointCount(mText) - Utf8.CodePointCount(StringView(mText, start, end - start));
			var allowed = Math.Max(maxLength - current, 0);
			var i = 0;
			while (i < clean.Length && allowed > 0)
			{
				Utf8.Decode(clean, i, var length);
				i += length;
				allowed--;
			}
			if (i < clean.Length)
				clean.RemoveToEnd(i);
		}
		if (start == end && clean.IsEmpty)
			return false;

		mText.Remove(start, end - start);
		mText.Insert(start, clean);
		mCaret = start + clean.Length;
		mAnchor = mCaret;
		mDesiredX = -1;
		PublishText();
		PublishSelection();
		return true;
	}

	public void InsertText(StringView text)
	{
		if (mIsReadOnly)
			return;
		if (bComposing)
			CancelComposition();
		ReplaceRange(mSelStart, mSelEnd, text);
	}

	void DeleteBackward(bool word)
	{
		if (mHasSel) { ReplaceRange(mSelStart, mSelEnd, ""); return; }
		if (mCaret <= 0) return;
		let start = word ? mSegmenter.PreviousWord(mText, mCaret) : mSegmenter.PreviousCluster(mText, mCaret);
		ReplaceRange(start, mCaret, "");
	}

	void DeleteForward(bool word)
	{
		if (mHasSel) { ReplaceRange(mSelStart, mSelEnd, ""); return; }
		if (mCaret >= mText.Length) return;
		let end = word ? mSegmenter.NextWord(mText, mCaret) : mSegmenter.NextCluster(mText, mCaret);
		ReplaceRange(mCaret, end, "");
	}

	void MoveTo(int index, bool extend)
	{
		mCaret = SnapToCluster(Math.Clamp(index, 0, mText.Length));
		if (!extend)
			mAnchor = mCaret;
		PublishSelection();
	}

	public void SelectAll()
	{
		mAnchor = 0;
		mCaret = mText.Length;
		PublishSelection();
	}

	public void Select(int startUtf16, int length)
	{
		mAnchor = SnapToCluster(Utf8.FromUtf16(mText, Math.Max(startUtf16, 0)));
		mCaret = SnapToCluster(Utf8.FromUtf16(mText, Math.Max(startUtf16, 0) + Math.Max(length, 0)));
		PublishSelection();
	}

	public void Copy()
	{
		let clipboard = (mContext.mWidgetHost != null) ? mContext.mWidgetHost.GetClipboard() : null;
		if (clipboard != null && mHasSel)
			clipboard.SetText(StringView(mText, mSelStart, mSelEnd - mSelStart));
	}

	public void Cut()
	{
		if (!mHasSel)
			return;
		Copy();
		if (!mIsReadOnly)
			ReplaceRange(mSelStart, mSelEnd, "");
	}

	public void Paste()
	{
		let clipboard = (mContext.mWidgetHost != null) ? mContext.mWidgetHost.GetClipboard() : null;
		if (mIsReadOnly || clipboard == null)
			return;
		let text = scope String();
		if (clipboard.GetText(text))
			InsertText(text);
	}

	protected override Result<Value, CallError> OnInvokeMethod(MethodDescriptor method, List<Value> arguments)
	{
		if (method == sSelectAll) SelectAll();
		else if (method == sSelect) Select((int)arguments[0].AsInt(), (int)arguments[1].AsInt());
		else if (method == sClear) { if (!mIsReadOnly) { CancelComposition(); ReplaceRange(0, mText.Length, ""); } }
		else if (method == sInsertText) InsertText(arguments[0].AsString());
		else if (method == sCut) Cut();
		else if (method == sCopy) Copy();
		else if (method == sPaste) Paste();
		else if (method == sSetCaret) MoveTo(Utf8.FromUtf16(mText, (int)arguments[0].AsInt()), false);
		else return base.OnInvokeMethod(method, arguments);
		return .Ok(Value.sNone);
	}

	// ---- Keyboard / text input ---------------------------------------------------------------------------------------

	void MoveHorizontal(int direction, bool word, bool extend)
	{
		mDesiredX = -1;
		if (!extend && mHasSel && !word)
		{
			MoveTo((direction < 0) ? mSelStart : mSelEnd, false);
			return;
		}
		int target;
		if (word)
			target = (direction < 0) ? mSegmenter.PreviousWord(mText, mCaret) : mSegmenter.NextWord(mText, mCaret);
		else
			target = Metrics.MoveVisual(mCaret, direction);
		MoveTo(target, extend);
	}

	void MoveVertical(int direction, bool extend)
	{
		if (mDesiredX < 0)
			mDesiredX = Metrics.GetCaretRect(mCaret).mX;
		MoveTo(Metrics.MoveLine(mCaret, direction, mDesiredX), extend);
	}

	public override void OnKeyDown(ref KeyEvent e)
	{
		if (bComposing)
			return;     // the IME owns the keys while composing

		let ctrl = (e.mModifiers & .Control) != 0;
		let shift = (e.mModifiers & .Shift) != 0;
		let readOnly = mIsReadOnly;

		switch (e.mKey)
		{
		case .Left: MoveHorizontal(-1, ctrl, shift); e.bHandled = true;
		case .Right: MoveHorizontal(1, ctrl, shift); e.bHandled = true;
		case .Home: mDesiredX = -1; MoveTo(ctrl ? 0 : Metrics.GetLineStart(mCaret), shift); e.bHandled = true;
		case .End: mDesiredX = -1; MoveTo(ctrl ? mText.Length : Metrics.GetLineEnd(mCaret), shift); e.bHandled = true;
		case .Up: if (mIsMultiline) { MoveVertical(-1, shift); e.bHandled = true; }
		case .Down: if (mIsMultiline) { MoveVertical(1, shift); e.bHandled = true; }
		case .Backspace: if (!readOnly) DeleteBackward(ctrl); e.bHandled = true;
		case .Delete:
			if (shift && !ctrl) Cut();
			else if (!readOnly) DeleteForward(ctrl);
			e.bHandled = true;
		case .Insert:
			if (ctrl) { Copy(); e.bHandled = true; }
			else if (shift) { Paste(); e.bHandled = true; }
		case .Enter:
			if (mIsMultiline) { if (!readOnly) InsertText("\n"); }
			else
			{
				let args = scope List<Value>();
				args.Add(Value.FromString(mContext.mStrings.InternTransient(mText)));
				RaiseEvent(sSubmitted, args);
			}
			e.bHandled = true;
		case .Tab:
			if (mProperties.Get(sAcceptsTab).AsBool() && !readOnly) { InsertText("\t"); e.bHandled = true; }
		case .A: if (ctrl) { SelectAll(); e.bHandled = true; }
		case .C: if (ctrl) { Copy(); e.bHandled = true; }
		case .X: if (ctrl) { Cut(); e.bHandled = true; }
		case .V: if (ctrl) { Paste(); e.bHandled = true; }
		default:
		}
	}

	public override void OnTextInput(ref TextInputEvent e)
	{
		if (mIsReadOnly)
			return;
		InsertText(e.mText);
		e.bHandled = true;
	}

	// ---- Pointer -----------------------------------------------------------------------------------------------------

	int HitIndex(float x, float y) => SnapToCluster(Math.Clamp(Metrics.HitTest(x, y), 0, mText.Length));

	public override void OnPointerDown(ref PointerEvent e)
	{
		if (e.mButton != .Left)
			return;
		if (bComposing)
			CommitComposition();

		let index = HitIndex(e.mLocalX, e.mLocalY);
		mDesiredX = -1;
		if (e.mClickCount <= 1)
		{
			MoveTo(index, (e.mModifiers & .Shift) != 0);
		}
		else if (e.mClickCount == 2)
		{
			mAnchor = mSegmenter.WordStart(mText, index);
			mCaret = mSegmenter.WordEnd(mText, index);
			PublishSelection();
		}
		else
		{
			// Triple click selects the line (the whole text in a single-line box).
			mAnchor = mIsMultiline ? Metrics.GetLineStart(index) : 0;
			mCaret = mIsMultiline ? Metrics.GetLineEnd(index) : mText.Length;
			PublishSelection();
		}
		bDragging = true;
		e.bHandled = true;
	}

	public override void OnPointerMove(ref PointerEvent e)
	{
		if (bDragging)
			MoveTo(HitIndex(e.mLocalX, e.mLocalY), true);
	}

	public override void OnPointerUp(ref PointerEvent e)
	{
		if (e.mButton == .Left && bDragging)
		{
			bDragging = false;
			e.bHandled = true;
		}
	}

	public override void OnPointerCancel()
	{
		bDragging = false;
	}

	public override void OnFocusGained(FocusReason reason)
	{
		base.OnFocusGained(reason);
		if (reason == .Keyboard)
			SelectAll();    // tabbing into a text box selects its content, like standard controls
		UpdateCaretRect();
	}

	public override void OnFocusLost()
	{
		base.OnFocusLost();
		bDragging = false;
		CancelComposition();
	}

	// ---- ITextInputClient (IME) ---------------------------------------------------------------------------------------

	public void GetSelection(out int start, out int end)
	{
		start = Utf8.ToUtf16(mText, mSelStart);
		end = Utf8.ToUtf16(mText, mSelEnd);
	}

	public void SetSelection(int start, int end)
	{
		Select(start, end - start);
	}

	public void ReplaceText(int start, int end, StringView text)
	{
		if (mIsReadOnly)
			return;
		CancelComposition();
		ReplaceRange(Utf8.FromUtf16(mText, start), Utf8.FromUtf16(mText, end), text);
	}

	void PublishComposition()
	{
		SetState(sIsComposing, Value.FromBool(bComposing));
		SetState(sCompositionText, Value.FromString(mContext.mStrings.InternTransient(mComposition)));
	}

	// Pre-edit text while an IME converts. `cursor` is a UTF-16 offset inside `text`. Empty text ends the composition.
	public void SetComposition(StringView text, int cursor)
	{
		if (text.IsEmpty)
		{
			CancelComposition();
			return;
		}
		if (mIsReadOnly)
			return;

		if (!bComposing)
		{
			if (mHasSel)
				ReplaceRange(mSelStart, mSelEnd, "");
			mCompositionStart = mCaret;
			bComposing = true;
		}
		mComposition.Set(text);
		mCompositionCursor = cursor;
		PublishComposition();
		UpdateCaretRect();
	}

	void CancelComposition()
	{
		if (!bComposing && mComposition.IsEmpty)
			return;
		bComposing = false;
		mComposition.Clear();
		PublishComposition();
	}

	public void CommitComposition()
	{
		if (!bComposing)
			return;
		let committed = scope String(mComposition);
		bComposing = false;
		mComposition.Clear();
		PublishComposition();
		ReplaceRange(mCompositionStart, mCompositionStart, committed);
	}

	// Screen rectangle of the caret (start of the composition while composing), for the IME candidate window.
	public RectF GetCaretRect()
	{
		let local = Metrics.GetCaretRect(bComposing ? mCompositionStart : mCaret);
		let origin = GetRootPosition();
		let root = RectF(origin.mX + local.mX, origin.mY + local.mY, local.mWidth, local.mHeight);
		return (mContext.mWidgetHost != null) ? mContext.mWidgetHost.RootToScreen(root) : root;
	}

	public int GetTextLength() => Utf8.Utf16Length(mText);
}
