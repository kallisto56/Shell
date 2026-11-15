namespace Shell.Simulation;

using System;
using System.Collections;
using Shell.Core;

// Decides, per operation, whether the simulation delays, fails or cancels it. Rules are checked in order; the first
// matching rule whose probability roll succeeds wins. The roll uses a seeded generator, so the same scenario produces the
// same sequence of faults on every run.
class FaultInjector : IFaultInjector
{
	public List<FaultRule> mRules = new .() ~ DeleteContainerAndItems!(_);
	IdGenerator mRandom;
	public int mEvaluations;

	public this(uint64 seed = 1)
	{
		mRandom = new IdGenerator(seed);
	}

	public ~this()
	{
		delete mRandom;
	}

	public void AddRule(FaultRule rule)
	{
		mRules.Add(rule);
	}

	public void Clear()
	{
		mRules.ClearAndDeleteItems();
	}

	public FaultDecision Evaluate(StringView operation, StringView target)
	{
		mEvaluations++;
		for (let rule in mRules)
		{
			if (!Matches(rule.mOperation, operation) || !(rule.mTargetPattern.IsEmpty || Matches(rule.mTargetPattern, target)))
				continue;

			if (rule.mProbability < 1)
			{
				let roll = (double)(mRandom.Next().mValue >> 11) / 9007199254740992.0;    // 53 bits -> [0,1)
				if (roll >= (double)rule.mProbability)
					continue;
			}

			FaultDecision decision = default;
			decision.mKind = rule.mKind;
			decision.mDelaySeconds = rule.mDelaySeconds;
			decision.mErrorCode = rule.mErrorCode;
			decision.mErrorMessage = rule.mErrorMessage;
			return decision;
		}
		return default;
	}

	// '*' matches any run of characters, comparison ignores case.
	static public bool Matches(StringView pattern, StringView text)
	{
		return MatchFrom(pattern, 0, text, 0);
	}

	static bool MatchFrom(StringView pattern, int p, StringView text, int t)
	{
		var p;
		var t;
		while (p < pattern.Length)
		{
			if (pattern[p] == '*')
			{
				while (p < pattern.Length && pattern[p] == '*')
					p++;
				if (p == pattern.Length)
					return true;
				for (var i = t; i <= text.Length; i++)
				{
					if (MatchFrom(pattern, p, text, i))
						return true;
				}
				return false;
			}
			if (t >= text.Length || pattern[p].ToLower != text[t].ToLower)
				return false;
			p++;
			t++;
		}
		return t == text.Length;
	}
}
