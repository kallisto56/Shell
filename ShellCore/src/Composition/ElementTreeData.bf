namespace Shell.Composition;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Elements;
using Shell.Blueprints;
using Shell.Animation;

class ElementTreeData
{
	public List<LayerDefinition> mLayers = new .() ~ DeleteContainerAndItems!(_);
	public ElementNodeData mRoot ~ delete _;
}
