namespace Shell.Runtime;

using System;
using System.Collections;
using Shell.Core;
using Shell.Reflection;
using Shell.Binding;
using Shell.Widgets;
using Shell.Elements;

// Resolves binding sources inside a RuntimeContext.
//   built in : Constant, TimeBuiltin, GlobalVariable, StyleToken (via IThemeProvider), WidgetProperty (by stable id),
//              OwnerProperty (the Widget owning the bound element), ParentProperty (nearest ancestor Widget with the property)
//   plugged  : BlueprintVariable, AnimationInput are provided by the Blueprint host / animation system through Register()
// Every failure produces a diagnostic with the binding owner as source and falls back to the binding's fallback value.
class RuntimeBindingResolver : IBindingResolver
{
	RuntimeContext mContext;
	public IThemeProvider mThemes;
	IBindingResolver[16] mProviders;
	RuntimeObject mLastSource;

	public this(RuntimeContext context)
	{
		mContext = context;
	}

	public void Register(BindingSourceKind kind, IBindingResolver provider)
	{
		mProviders[(int)kind] = provider;
	}

	void Fail(StringView code, StringView message, RuntimeObject owner)
	{
		mContext.mDiagnostics.Error(code, message, (owner != null) ? owner.mStableId : StableId.sNone);
	}

	// Finds the object + descriptor a property-style source points at.
	bool FindProperty(BindingSource source, RuntimeObject context, out IPropertyHost host, out PropertyDescriptor property)
	{
		host = null;
		property = null;

		switch (source.mKind)
		{
		case .WidgetProperty:
			host = mContext.FindByStableId(source.mTarget);
			if (host == null)
			{
				Fail("BND0001", scope $"Binding source object {source.mTarget} does not exist.", context);
				return false;
			}
		case .OwnerProperty:
			host = FindOwnerWidget(context);
			if (host == null)
			{
				Fail("BND0002", "Binding refers to its owner widget, but the bound object has none.", context);
				return false;
			}
		case .ParentProperty:
			for (var w = FindOwnerWidget(context); w != null; w = w.mParent)
			{
				let candidate = w.mParent;
				if (candidate != null && candidate.GetDescriptor().FindProperty(source.mMember) != null)
				{
					host = candidate;
					break;
				}
			}
			if (host == null)
			{
				Fail("BND0003", scope $"No ancestor widget has a property '{source.mMember}'.", context);
				return false;
			}
		default:
			return false;
		}

		property = host.GetDescriptor().FindProperty(source.mMember);
		if (property == null)
		{
			Fail("BND0004", scope $"Type '{host.GetDescriptor().mName}' has no property '{source.mMember}'.", context);
			return false;
		}
		return true;
	}

	static Widget FindOwnerWidget(RuntimeObject context)
	{
		if (let widget = context as Widget)
			return widget;
		if (let element = context as Element)
			return element.mTree.mOwner as Widget;
		return null;
	}

	public RuntimeObject GetLastSourceObject() => mLastSource;

	public IObservable Observe(BindingSource source, RuntimeObject context)
	{
		mLastSource = null;
		switch (source.mKind)
		{
		case .Constant:
			return null;
		case .TimeBuiltin:
			return mContext.mTime.Observe(source.mTime);
		case .GlobalVariable:
		{
			let observable = mContext.mGlobals.Observe(source.mMember);
			if (observable == null)
				Fail("BND0005", scope $"Global variable '{source.mMember}' is not defined.", context);
			return observable;
		}
		case .StyleToken:
			return (mThemes != null) ? mThemes.ObserveToken(source.mMember) : null;
		case .WidgetProperty, .OwnerProperty, .ParentProperty:
		{
			if (FindProperty(source, context, var host, var property))
			{
				mLastSource = host as RuntimeObject;
				return host.GetObservable(property);
			}
			return null;
		}
		default:
		{
			let provider = mProviders[(int)source.mKind];
			if (provider == null)
			{
				Fail("BND0006", scope $"No provider is registered for binding source kind {source.mKind}.", context);
				return null;
			}
			let observable = provider.Observe(source, context);
			mLastSource = provider.GetLastSourceObject();
			return observable;
		}
		}
	}

	public Result<Value> Read(BindingSource source, RuntimeObject context)
	{
		switch (source.mKind)
		{
		case .Constant:
			return .Ok(source.mConstant);
		case .TimeBuiltin:
			return .Ok(Value.FromFloat(mContext.mTime.Get(source.mTime)));
		case .GlobalVariable:
		{
			if (mContext.mGlobals.Get(source.mMember) case .Ok(let value))
				return .Ok(value);
			Fail("BND0005", scope $"Global variable '{source.mMember}' is not defined.", context);
			return .Err;
		}
		case .StyleToken:
		{
			if (mThemes != null && mThemes.GetToken(source.mMember) case .Ok(let value))
				return .Ok(value);
			Fail("BND0007", scope $"Design token '{source.mMember}' is not defined.", context);
			return .Err;
		}
		case .WidgetProperty, .OwnerProperty, .ParentProperty:
		{
			if (!FindProperty(source, context, var host, var property))
				return .Err;
			return .Ok(host.GetProperty(property));
		}
		default:
		{
			let provider = mProviders[(int)source.mKind];
			if (provider == null)
			{
				Fail("BND0006", scope $"No provider is registered for binding source kind {source.mKind}.", context);
				return .Err;
			}
			return provider.Read(source, context);
		}
		}
	}

	public Result<void> Write(BindingSource source, RuntimeObject context, Value value)
	{
		switch (source.mKind)
		{
		case .GlobalVariable:
		{
			if (mContext.mGlobals.Set(source.mMember, value, mContext.mDiagnostics) case .Ok)
				return .Ok;
			return .Err;
		}
		case .WidgetProperty, .OwnerProperty, .ParentProperty:
		{
			if (!FindProperty(source, context, var host, var property))
				return .Err;
			if (host.SetProperty(property, value) case .Err(let error))
			{
				Fail("BND0008", scope $"Cannot write property '{property.mName}': {error}.", context);
				return .Err;
			}
			return .Ok;
		}
		case .Constant, .TimeBuiltin, .StyleToken:
		{
			Fail("BND0009", scope $"Binding source kind {source.mKind} is read-only.", context);
			return .Err;
		}
		default:
		{
			let provider = mProviders[(int)source.mKind];
			if (provider == null)
			{
				Fail("BND0006", scope $"No provider is registered for binding source kind {source.mKind}.", context);
				return .Err;
			}
			return provider.Write(source, context, value);
		}
		}
	}
}
