namespace Shell.Rendering;

using System;
using Shell.Elements;

// One visual effect (blur, shadow, ...) applied to the rendered output of a subtree or to what is behind it.
//
// Contract:
//   * GetPadding: pixels the group surface must grow on every side so the effect has room (a blur reads and writes beyond the box).
//   * Apply: reads `source` and returns the result surface. It may return `source` itself or a surface acquired from the pool; it never
//     releases `source` - the caller releases the previous surface when a different one is returned. Surfaces are premultiplied alpha.
//   * Effects of a group run in list order, each on the output of the previous one.
interface IEffectPass
{
	EffectKind GetKind();
	StringView GetCustomName();                 // identifies EffectKind.Custom passes
	float GetPadding(EffectDescriptor effect);
	IRenderSurface Apply(IEffectContext context, IRenderSurface source, EffectDescriptor effect);
}
