namespace Shell.Rendering;

using System;
using System.Collections;
using Shell.Elements;

// The effect passes available to a renderer. Built-in kinds are registered by the renderer; custom passes are registered by name
// and referenced from EffectDescriptor.mCustomName. Owns the passes.
class EffectPassRegistry
{
	List<IEffectPass> mPasses = new .() ~ DeleteContainerAndItems!(_);

	public void Register(IEffectPass pass)
	{
		mPasses.Add(pass);
	}

	public IEffectPass Find(EffectKind kind, StringView customName)
	{
		for (let pass in mPasses)
		{
			if (pass.GetKind() != kind)
				continue;
			if (kind != .Custom || pass.GetCustomName() == customName)
				return pass;
		}
		return null;
	}
}
