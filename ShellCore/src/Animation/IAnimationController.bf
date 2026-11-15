namespace Shell.Animation;

using System;
using Shell.Core;
using Shell.Styling;

// Evaluates authored animation (clips, state machines, blend trees) for one composition instance.
// Runs in the Animation phase. Rules:
//   * a controller writes only to PropertyLayer.Animation, weighted and blended by its own state machine;
//   * two controllers targeting the same (object, property) in the same instance is an authoring error reported by
//     validation (AnimationConflict) and resolved deterministically by controller order at runtime;
//   * state machine inputs are written by Blueprints / widgets before the phase starts and are read-only inside it.
interface IAnimationController
{
	StableId GetId();
	int GetOrder();
	void Evaluate(FrameContext frame, IContributionSink sink);
	void SetInput(StringView name, Value value);   // trigger inputs use Value.FromBool(true)
}
