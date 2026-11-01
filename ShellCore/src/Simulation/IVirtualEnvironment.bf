namespace Shell.Simulation;

using System;
using Shell.Platform;

// The simulated operating system used by the editor: a complete PlatformServices set backed by virtual state (virtual
// file system, virtual windows and monitors, controllable clock, scripted faults). Nothing in it can reach the host.
interface IVirtualEnvironment
{
	PlatformServices GetServices();
	IFaultInjector GetFaultInjector();
	void Reset();                                   // back to the scenario's initial state
	void Advance(double seconds);                   // advances the simulated clock and completes due operations
	bool SaveSnapshot(String outSnapshotId);        // checkpoint for "try the delete flow again"
	bool RestoreSnapshot(StringView snapshotId);
}
