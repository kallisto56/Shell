namespace Shell.Core;

using System;

// A unit of per-frame work (input router, blueprint scheduler, animation evaluator, layout, ...).
interface IRuntimeSystem
{
	UpdatePhase GetPhase();
	int GetOrder();
	void Update(FrameContext frame);
}
