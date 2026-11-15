namespace Shell.Simulation;

using System;

interface IFaultInjector
{
	FaultDecision Evaluate(StringView operation, StringView target);
}
