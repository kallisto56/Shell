namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

class SetZIndexCommand : DefinitionCommand
{
	ElementNodeData mElement;
	int mOld;
	int mNew;

	public this(DefinitionEditSession session, ElementNodeData element, int zIndex) : base(session, "Change draw order")
	{
		mElement = element;
		mOld = element.mZIndex;
		mNew = zIndex;
	}

	protected override void Apply() => mElement.mZIndex = mNew;
	protected override void Revert() => mElement.mZIndex = mOld;
}
