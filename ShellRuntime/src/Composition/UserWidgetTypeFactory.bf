namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Elements;
using Shell.Widgets;
using Shell.Composition;

// Builds the TypeDescriptor that describes the public surface of a UserWidget definition: one property / event / method per exposed
// member, with kinds, defaults and parameters copied from the inner member it forwards to (so editors, bindings, Blueprints and the
// serializer see an ordinary typed widget).
//
// Types are cached per definition and reused while the exposed interface keeps the same signature, which is what lets a definition
// edit propagate without invalidating bindings on its instances. A changed signature creates a new type; old types stay alive until
// shutdown (live instances switch via UserWidget.SwapType).
class UserWidgetTypeFactory
{
	class Entry
	{
		public String mSignature = new .() ~ delete _;
		public TypeDescriptor mType;
	}

	RuntimeContext mContext;
	public CompositionRegistry mRegistry;
	Dictionary<StableId, Entry> mEntries = new .() ~ DeleteDictionaryAndValues!(_);
	List<TypeDescriptor> mTypes = new .() ~ DeleteContainerAndItems!(_);
	int mCounter;

	public this(RuntimeContext context)
	{
		mContext = context;
	}

	// Inner member described by an exposed member (any of the three may be set, depending on the exposed kind).
	struct Inner
	{
		public PropertyDescriptor mProperty;
		public EventDescriptor mEvent;
		public MethodDescriptor mMethod;
		public bool mFound;
	}

	Inner ResolveInner(CompositionDefinition definition, DefinitionIndex index, ExposedMember member, int depth)
	{
		Inner result = default;
		if (depth > 16)
			return result;
		let found = index.Find(member.mInnerTarget);
		if (found case .Err)
			return result;
		let entry = found.Value;

		TypeDescriptor type = null;
		if (entry.mWidget != null)
		{
			if (entry.mWidget.mIsInstance)
			{
				let nested = (mRegistry != null) ? mRegistry.Find(entry.mWidget.mSourceDefinition) : null;
				if (nested != null)
					type = GetType(nested, depth + 1);
			}
			else
			{
				type = mContext.mTypes.Find(entry.mWidget.mTypeName);
			}
		}
		else if (entry.mElement != null)
		{
			type = entry.mElement.mTypeName.IsEmpty ? ElementTypes.TypeFor(entry.mElement.mKind) : mContext.mTypes.Find(entry.mElement.mTypeName);
		}
		if (type == null)
			return result;

		result.mProperty = type.FindProperty(member.mInnerMember);
		result.mEvent = type.FindEvent(member.mInnerMember);
		result.mMethod = type.FindMethod(member.mInnerMember);
		result.mFound = true;
		return result;
	}

	static void AppendSignature(String signature, ExposedMember member)
	{
		signature.AppendF("{}:{}:{}:{}:{};", (int)member.mKind, member.mPublicName, (int)member.mValueKind, member.bWritable ? 1 : 0, member.mInnerMember);
	}

	public TypeDescriptor GetType(CompositionDefinition definition, int depth = 0)
	{
		let signature = scope String();
		for (let member in definition.mExposed)
			AppendSignature(signature, member);

		if (mEntries.TryGetValue(definition.mId, let existing) && existing.mSignature == signature)
			return existing.mType;

		let index = DefinitionIndex.Build(definition.mRoot);
		defer delete index;

		mCounter++;
		let name = scope String();
		name.AppendF("UserWidget:{}#{}.{}", definition.mName, definition.mId, mCounter);
		let type = new TypeDescriptor(name, .Widget, UserWidget.sBaseType);

		for (let member in definition.mExposed)
		{
			let inner = ResolveInner(definition, index, member, depth);
			switch (member.mKind)
			{
			case .Property:
				if (inner.mProperty == null)
				{
					mContext.mDiagnostics.Warning("UWD0010", scope $"Exposed property '{member.mPublicName}' of '{definition.mName}' does not match a property of its target.", definition.mId);
					break;
				}
				type.AddProperty(new PropertyDescriptor(member.mPublicName, inner.mProperty.mValueKind)
				{
					mKind = member.bWritable ? .Value : .State,
					mDefault = inner.mProperty.mDefault,
					mInvalidates = .None,
					mFlags = member.bWritable ? (.Serialized | .Bindable) : .Bindable,
					mEnumType = inner.mProperty.mEnumType
				});

			case .Event:
				if (inner.mEvent == null)
				{
					mContext.mDiagnostics.Warning("UWD0011", scope $"Exposed event '{member.mPublicName}' of '{definition.mName}' does not match an event of its target.", definition.mId);
					break;
				}
				let ev = type.AddEvent(new EventDescriptor(member.mPublicName));
				for (let parameter in inner.mEvent.mParameters)
					ev.Param(parameter.mName, parameter.mKind);

			case .Method:
				if (inner.mMethod == null)
				{
					mContext.mDiagnostics.Warning("UWD0012", scope $"Exposed method '{member.mPublicName}' of '{definition.mName}' does not match a method of its target.", definition.mId);
					break;
				}
				let method = type.AddMethod(new MethodDescriptor(member.mPublicName));
				method.Returns(inner.mMethod.mReturnKind);
				for (let parameter in inner.mMethod.mParameters)
					method.mParameters.Add(new ParameterDescriptor(parameter.mName, parameter.mKind) { mDefault = parameter.mDefault });

			case .Variable:
				mContext.mDiagnostics.Warning("UWD0013", scope $"Exposed variable '{member.mPublicName}' needs the Blueprint host and is not available yet.", definition.mId);
			}
		}

		if (!mContext.mTypes.Register(type, mContext.mDiagnostics, false))
		{
			delete type;
			return UserWidget.sBaseType;
		}
		mTypes.Add(type);

		if (mEntries.TryGetValue(definition.mId, let old))
		{
			old.mSignature.Set(signature);
			old.mType = type;
		}
		else
		{
			let entry = new Entry();
			entry.mSignature.Set(signature);
			entry.mType = type;
			mEntries[definition.mId] = entry;
		}
		return type;
	}
}
