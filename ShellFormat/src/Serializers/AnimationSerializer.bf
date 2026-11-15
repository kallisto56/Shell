namespace Shell.Format;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Elements;
using Shell.Blueprints;
using Shell.Composition;
using Shell.Animation;
using Shell.Styling;
using Shell.Serialization;

static class AnimationSerializer
{
	// ---- Clips ----
	static public void WriteClip(AnimationClip clip, DocumentNode node, SerializationContext context)
	{
		let w = scope NodeWriter(node, context);
		w.Str("Name", clip.mName);
		w.FloatAlways("Duration", clip.mDuration);
		w.Bool("Loop", clip.bLoop);

		if (clip.mTracks.Count > 0)
		{
			let group = w.Group("tracks");
			for (let track in clip.mTracks)
			{
				let tn = NodeWriter.AddNode(group, "Track", track.mId);
				let tw = scope NodeWriter(tn, context);
				tw.IdAlways("Target", track.mTarget);
				tw.Str("Property", track.mProperty);
				let keys = tw.Group("keys");
				for (let key in track.mKeys)
				{
					let kn = NodeWriter.AddNode(keys, "Key", .sNone);
					let kw = scope NodeWriter(kn, context);
					kw.FloatAlways("Time", key.mTime);
					kw.Val("Value", key.mValue);
					kw.EnumIf("Interpolation", key.mInterpolation, InterpolationKind.Step);
					kw.Float("InTangent", key.mInTangent);
					kw.Float("OutTangent", key.mOutTangent);
				}
			}
		}
		if (clip.mEvents.Count > 0)
		{
			let group = w.Group("events");
			for (let ev in clip.mEvents)
			{
				let en = NodeWriter.AddNode(group, "Event", .sNone);
				let ew = scope NodeWriter(en, context);
				ew.FloatAlways("Time", ev.mTime);
				ew.Str("Name", ev.mName);
			}
		}
	}

	static public AnimationClip ReadClip(DocumentNode node, SerializationContext context)
	{
		let r = scope NodeReader(node, context);
		let clip = new AnimationClip();
		clip.mId = node.mId;
		r.StrInto("Name", clip.mName);
		clip.mDuration = (float)r.Float("Duration");
		clip.bLoop = r.Bool("Loop");

		let tracks = r.Group("tracks");
		if (tracks != null)
		{
			for (let tn in tracks.mNodes)
			{
				let tr = scope NodeReader(tn, context);
				let track = new AnimationTrack();
				track.mId = tn.mId;
				track.mTarget = tr.Id("Target", true);
				track.mProperty = tr.Str("Property", true);
				let keys = tr.Group("keys");
				if (keys != null)
				{
					for (let kn in keys.mNodes)
					{
						let kr = scope NodeReader(kn, context);
						Keyframe key = default;
						key.mTime = (float)kr.Float("Time");
						key.mValue = kr.Val("Value");
						key.mInterpolation = kr.Enum("Interpolation", InterpolationKind.Step);
						key.mInTangent = (float)kr.Float("InTangent");
						key.mOutTangent = (float)kr.Float("OutTangent");
						kr.ReportUnknown();
						track.mKeys.Add(key);
					}
				}
				tr.ReportUnknown();
				clip.mTracks.Add(track);
			}
		}

		let events = r.Group("events");
		if (events != null)
		{
			for (let en in events.mNodes)
			{
				let er = scope NodeReader(en, context);
				AnimationEvent ev = default;
				ev.mTime = (float)er.Float("Time");
				ev.mName = er.Str("Name", true);
				er.ReportUnknown();
				clip.mEvents.Add(ev);
			}
		}
		r.ReportUnknown();
		return clip;
	}

	// ---- State machines ----
	static public void WriteMachine(StateMachineDef machine, DocumentNode node, SerializationContext context)
	{
		let w = scope NodeWriter(node, context);
		w.Str("Name", machine.mName);
		w.Id("Entry", machine.mEntryState);

		if (machine.mInputs.Count > 0)
		{
			let group = w.Group("inputs");
			for (let input in machine.mInputs)
			{
				let n = NodeWriter.AddNode(group, "Input", input.mId);
				let iw = scope NodeWriter(n, context);
				iw.Str("Name", input.mName);
				iw.Enum("Kind", input.mKind);
				if (!input.mDefault.mIsNone) iw.Val("Default", input.mDefault);
			}
		}
		if (machine.mStates.Count > 0)
		{
			let group = w.Group("states");
			for (let state in machine.mStates)
			{
				let n = NodeWriter.AddNode(group, "State", state.mId);
				let sw = scope NodeWriter(n, context);
				sw.Str("Name", state.mName);
				sw.Enum("Content", state.mContent);
				sw.Id("ContentId", state.mContentId);
				sw.Float("Speed", state.mSpeed, 1);
				sw.Float("X", state.mX);
				sw.Float("Y", state.mY);
				for (int i < state.mEnterEvents.Count)
					sw.Str(scope $"enter{i}", state.mEnterEvents[i]);
			}
		}
		if (machine.mTransitions.Count > 0)
		{
			let group = w.Group("transitions");
			for (let transition in machine.mTransitions)
			{
				let n = NodeWriter.AddNode(group, "Transition", transition.mId);
				let tw = scope NodeWriter(n, context);
				tw.Id("From", transition.mFrom);
				tw.IdAlways("To", transition.mTo);
				tw.Float("Duration", transition.mDuration);
				tw.Bool("HasExitTime", transition.bHasExitTime);
				tw.Float("ExitTime", transition.mExitTime);
				tw.EnumIf("Interrupt", transition.mInterrupt, TransitionInterrupt.None);
				if (transition.mConditions.Count > 0)
				{
					let conditions = tw.Group("conditions");
					for (let condition in transition.mConditions)
					{
						let cn = NodeWriter.AddNode(conditions, "Condition", .sNone);
						let cw = scope NodeWriter(cn, context);
						cw.IdAlways("Input", condition.mInput);
						cw.Enum("Op", condition.mOp);
						if (!condition.mOperand.mIsNone) cw.Val("Operand", condition.mOperand);
					}
				}
			}
		}
		if (machine.mBlendTrees.Count > 0)
		{
			let group = w.Group("blendTrees");
			for (let tree in machine.mBlendTrees)
			{
				let n = NodeWriter.AddNode(group, "BlendTree", tree.mId);
				let bw = scope NodeWriter(n, context);
				bw.Str("Name", tree.mName);
				bw.Enum("Kind", tree.mKind);
				bw.Id("InputX", tree.mInputX);
				bw.Id("InputY", tree.mInputY);
				if (tree.mEntries.Count > 0)
				{
					let entries = bw.Group("entries");
					for (let entry in tree.mEntries)
					{
						let en = NodeWriter.AddNode(entries, "Entry", .sNone);
						let ew = scope NodeWriter(en, context);
						ew.IdAlways("Clip", entry.mClip);
						ew.Float("ThresholdX", entry.mThresholdX);
						ew.Float("ThresholdY", entry.mThresholdY);
					}
				}
			}
		}
	}

	static public StateMachineDef ReadMachine(DocumentNode node, SerializationContext context)
	{
		let r = scope NodeReader(node, context);
		let machine = new StateMachineDef();
		machine.mId = node.mId;
		r.StrInto("Name", machine.mName);
		machine.mEntryState = r.Id("Entry");

		let inputs = r.Group("inputs");
		if (inputs != null)
		{
			for (let n in inputs.mNodes)
			{
				let ir = scope NodeReader(n, context);
				let input = new AnimationInputDef();
				input.mId = n.mId;
				ir.StrInto("Name", input.mName, true);
				input.mKind = ir.Enum("Kind", AnimationInputKind.Bool);
				input.mDefault = ir.Val("Default");
				ir.ReportUnknown();
				machine.mInputs.Add(input);
			}
		}

		let states = r.Group("states");
		if (states != null)
		{
			for (let n in states.mNodes)
			{
				let sr = scope NodeReader(n, context);
				let state = new AnimationStateDef();
				state.mId = n.mId;
				sr.StrInto("Name", state.mName, true);
				state.mContent = sr.Enum("Content", StateContentKind.Empty);
				state.mContentId = sr.Id("ContentId");
				state.mSpeed = (float)sr.Float("Speed", 1);
				state.mX = (float)sr.Float("X");
				state.mY = (float)sr.Float("Y");
				for (var i = 0; sr.Has(scope $"enter{i}"); i++)
					state.mEnterEvents.Add(sr.Str(scope $"enter{i}"));
				sr.ReportUnknown();
				machine.mStates.Add(state);
			}
		}

		let transitions = r.Group("transitions");
		if (transitions != null)
		{
			for (let n in transitions.mNodes)
			{
				let tr = scope NodeReader(n, context);
				let transition = new StateTransition();
				transition.mId = n.mId;
				transition.mFrom = tr.Id("From");
				transition.mTo = tr.Id("To", true);
				transition.mDuration = (float)tr.Float("Duration");
				transition.bHasExitTime = tr.Bool("HasExitTime");
				transition.mExitTime = (float)tr.Float("ExitTime");
				transition.mInterrupt = tr.Enum("Interrupt", TransitionInterrupt.None);
				let conditions = tr.Group("conditions");
				if (conditions != null)
				{
					for (let cn in conditions.mNodes)
					{
						let cr = scope NodeReader(cn, context);
						TransitionCondition condition = default;
						condition.mInput = cr.Id("Input", true);
						condition.mOp = cr.Enum("Op", ConditionOp.IsTrue);
						condition.mOperand = cr.Val("Operand");
						cr.ReportUnknown();
						transition.mConditions.Add(condition);
					}
				}
				tr.ReportUnknown();
				machine.mTransitions.Add(transition);
			}
		}

		let trees = r.Group("blendTrees");
		if (trees != null)
		{
			for (let n in trees.mNodes)
			{
				let br = scope NodeReader(n, context);
				let tree = new BlendTreeDef();
				tree.mId = n.mId;
				br.StrInto("Name", tree.mName, true);
				tree.mKind = br.Enum("Kind", BlendTreeKind.Blend1D);
				tree.mInputX = br.Id("InputX");
				tree.mInputY = br.Id("InputY");
				let entries = br.Group("entries");
				if (entries != null)
				{
					for (let en in entries.mNodes)
					{
						let er = scope NodeReader(en, context);
						BlendTreeEntry entry = default;
						entry.mClip = er.Id("Clip", true);
						entry.mThresholdX = (float)er.Float("ThresholdX");
						entry.mThresholdY = (float)er.Float("ThresholdY");
						er.ReportUnknown();
						tree.mEntries.Add(entry);
					}
				}
				br.ReportUnknown();
				machine.mBlendTrees.Add(tree);
			}
		}
		r.ReportUnknown();
		return machine;
	}
}
