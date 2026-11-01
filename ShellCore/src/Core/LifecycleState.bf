namespace Shell.Core;

using System;

// Created -> Initialized -> Active -> Deactivating -> Destroyed. Transitions only move forward.
enum LifecycleState
{
	case Created;       // allocated, not registered yet
	case Initialized;   // has a handle and a stable id, children can be attached
	case Active;        // participates in update / input / rendering
	case Deactivating;  // destruction requested: skipped by traversals, still resolvable until the Commit phase
	case Destroyed;     // handle released, memory freed
}
