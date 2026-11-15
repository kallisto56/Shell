namespace Shell.Binding;

using System;
using System.Collections;
using Shell.Core;

static class ConverterPipeline
{
	static public Value Apply(List<ConverterStep> steps, Value input, StringPool strings)
	{
		var value = input;
		for (let step in steps)
			value = ApplyStep(step, value, strings);
		return value;
	}

	static Value ApplyStep(ConverterStep step, Value value, StringPool strings)
	{
		switch (step.mKind)
		{
		case .Not:
			return Value.FromBool(!value.AsBool());
		case .Negate:
			return (value.mKind == .Int) ? Value.FromInt(-value.mInt) : Value.FromFloat(-value.AsFloat());
		case .Scale:
			return Value.FromFloat(value.AsFloat() * step.mArg0.AsFloat(1));
		case .Offset:
			return Value.FromFloat(value.AsFloat() + step.mArg0.AsFloat());
		case .Clamp:
			return Value.FromFloat(Math.Clamp(value.AsFloat(), step.mArg0.AsFloat(), step.mArg1.AsFloat()));
		case .IsEmpty:
			return Value.FromBool(value.mIsNone || ((value.mKind == .String) && value.mString.IsEmpty));
		case .ToText:
		{
			let text = scope String();
			value.ToString(text);
			return Value.FromString(strings.Intern(text));
		}
		case .Select:
			return value.AsBool() ? step.mArg0 : step.mArg1;
		case .EqualsTo:
			return Value.FromBool(value.Equals(step.mArg0));
		case .GreaterThan:
			return Value.FromBool(value.AsFloat() > step.mArg0.AsFloat());
		case .Coalesce:
			return value.mIsNone ? step.mArg0 : value;
		}
	}
}
