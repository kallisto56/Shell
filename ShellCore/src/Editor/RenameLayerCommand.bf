namespace Shell.Editor;

using System;
using System.Collections;
using Shell.Core;
using Shell.Elements;
using Shell.Composition;
using Shell.Reflection;
using Shell.Binding;

class RenameLayerCommand : DefinitionCommand
{
	LayerDefinition mLayer;
	String mOld = new .() ~ delete _;
	String mNew = new .() ~ delete _;

	public this(DefinitionEditSession session, LayerDefinition layer, StringView name) : base(session, "Rename layer")
	{
		mLayer = layer;
		mOld.Set(layer.mName);
		mNew.Set(name);
	}

	protected override void Apply() => mLayer.mName.Set(mNew);
	protected override void Revert() => mLayer.mName.Set(mOld);
}
