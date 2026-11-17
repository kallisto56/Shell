namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

// Assigns an element to a layer (none = inherit from its parent). Ownership, layout and the element's identity do not change.
class SetElementLayerCommand : DefinitionCommand
{
	ElementNodeData mElement;
	StableId mOld;
	StableId mNew;

	public this(DefinitionEditSession session, ElementNodeData element, StableId layer) : base(session, "Move to layer")
	{
		mElement = element;
		mOld = element.mLayer;
		mNew = layer;
	}

	protected override void Apply() => mElement.mLayer = mNew;
	protected override void Revert() => mElement.mLayer = mOld;
}
