namespace Shell.Core;

using System;

// Fixed order of one frame. Every system runs in exactly one phase; inside a phase, systems run by ascending order
// value and then by registration order. Nothing outside the phase list may mutate shared state.
enum UpdatePhase
{
	case Input;         // platform events -> input routing -> Widget events (queued)
	case Timers;        // time sources, delays, scheduled work
	case Blueprints;    // queued events are executed to completion, in FIFO order
	case Animation;     // clips / state machines evaluate and write the Animation contribution layer
	case Bindings;      // dirty bindings re-evaluate, style rules resolve
	case Layout;        // measure / arrange for dirty subtrees
	case Commit;        // deferred tree mutations and object destruction are applied
	case Render;        // render lists are built and submitted (read-only phase)

	public const int cCount = 8;
}
