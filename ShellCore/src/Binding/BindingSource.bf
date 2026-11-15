namespace Shell.Binding;

using System;
using Shell.Core;

// Serializable description of where a bound value comes from.
struct BindingSource
{
	public BindingSourceKind mKind;
	public StableId mTarget;
	public StringView mMember;
	public Value mConstant;
	public TimeBuiltin mTime;
}
