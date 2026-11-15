namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Platform;

// Runs the deterministic update cycle (see UpdatePhase) over a RuntimeContext.
//
// The kernel does not read a clock itself: Tick() receives the elapsed real time. The real shell passes measured time,
// the simulation and tests pass scripted time, so a run is reproducible.
//
// Traversal rules: Input, Animation, Bindings, Layout and Render run with the context's TraversalGuard entered, so any
// tree change requested by code running in those phases is queued and applied in Commit. Timers, Blueprints and Commit run
// without an active traversal (Blueprint nodes may create or destroy objects immediately).
class ShellKernel
{
	public const double cMaxDeltaSeconds = 0.25;

	public RuntimeContext mContext;
	public RuntimeSystemList mSystems = new .() ~ delete _;

	public float mTimeScale = 1;
	public bool bPaused;
	public double mTime;
	public double mUnscaledTime;
	public uint64 mFrameIndex;

	public this(RuntimeContext context)
	{
		mContext = context;
	}

	public void AddSystem(IRuntimeSystem system) => mSystems.Add(system);
	public bool RemoveSystem(IRuntimeSystem system) => mSystems.Remove(system);

	// Advances one frame. unscaledDelta is clamped (debugger pauses, window drags) so simulations never see huge steps.
	public void Tick(double unscaledDelta)
	{
		var unscaled = Math.Max(unscaledDelta, 0.0);
		unscaled = Math.Min(unscaled, cMaxDeltaSeconds);
		let scaled = bPaused ? 0.0 : unscaled * (double)mTimeScale;

		mTime += scaled;
		mUnscaledTime += unscaled;

		FrameContext frame = default;
		frame.mFrameIndex = mFrameIndex;
		frame.mTime = mTime;
		frame.mUnscaledTime = mUnscaledTime;
		frame.mDeltaTime = (float)scaled;
		frame.mUnscaledDeltaTime = (float)unscaled;
		frame.mTimeScale = bPaused ? 0 : mTimeScale;
		mContext.mFrame = frame;

		for (int i < UpdatePhase.cCount)
			RunPhase((UpdatePhase)i, frame);

		mFrameIndex++;
	}

	// Convenience for hosts that own a clock.
	public double TickFromClock(IClock clock, ref double previousSeconds)
	{
		let now = clock.GetMonotonicSeconds();
		let delta = now - previousSeconds;
		previousSeconds = now;
		Tick(delta);
		return delta;
	}

	void RunPhase(UpdatePhase phase, FrameContext frame)
	{
		var current = frame;
		current.mPhase = phase;
		mContext.mFrame = current;

		if (phase == .Timers)
			mContext.mTime.Update(current);

		let bTraversing = phase == .Input || phase == .Animation || phase == .Bindings || phase == .Layout || phase == .Render;
		if (bTraversing)
			mContext.mTraversal.Enter();

		for (let system in mSystems.GetPhase(phase))
			system.Update(current);

		if (bTraversing)
			mContext.mTraversal.Exit();

		if (phase == .Commit)
		{
			mContext.mMutations.Flush(mContext);
			mContext.FlushDestruction();
			mContext.mStrings.CollectGarbage();
		}
	}
}
