namespace Shell.Render;

using System;
using System.Collections;
using Juno;
using Shell.Core;

// Resolves (family, size) to a loaded Juno Font. Families are registered with a font file; the usual Windows families are
// registered by default. Unknown families fall back to "Segoe UI" (reported once). Fonts are cached per family and pixel size.
class FontCatalog
{
	Device* mDevice;
	DiagnosticSink mSink;
	Dictionary<String, String> mFamilies = new .() ~ DeleteDictionaryAndKeysAndValues!(_);
	Dictionary<String, Font> mFonts = new .() ~ DeleteDictionaryAndKeysAndValues!(_);
	HashSet<String> mReported = new .() ~ DeleteContainerAndItems!(_);

	public this(Device* device, DiagnosticSink sink)
	{
		mDevice = device;
		mSink = sink;
		RegisterFamily("Segoe UI", "C:/Windows/Fonts/segoeui.ttf");
		RegisterFamily("Arial", "C:/Windows/Fonts/arial.ttf");
		RegisterFamily("Tahoma", "C:/Windows/Fonts/tahoma.ttf");
		RegisterFamily("Calibri", "C:/Windows/Fonts/calibri.ttf");
		RegisterFamily("Consolas", "C:/Windows/Fonts/consola.ttf");
		RegisterFamily("Segoe UI Symbol", "C:/Windows/Fonts/seguisym.ttf");
	}

	public void RegisterFamily(StringView family, StringView path)
	{
		let key = scope String(family);
		if (mFamilies.TryGetValue(key, let existing))
		{
			existing.Set(path);
			return;
		}
		mFamilies[new String(family)] = new String(path);
	}

	void ReportOnce(StringView code, StringView message)
	{
		let key = scope String(message);
		if (mReported.Contains(key))
			return;
		mReported.Add(new String(message));
		if (mSink != null)
			mSink.Warning(code, message);
	}

	public Font Get(StringView family, float size)
	{
		let pixels = Math.Max((int)Math.Round(size), 1);
		var name = family;
		if (!mFamilies.ContainsKey(scope String(name)))
		{
			ReportOnce("REN0001", scope $"Font family '{family}' is not registered; Segoe UI is used instead.");
			name = "Segoe UI";
		}

		let key = scope String();
		key.AppendF("{}|{}", name, pixels);
		if (mFonts.TryGetValue(key, let cached))
			return cached;

		if (!mFamilies.TryGetValue(scope String(name), let path))
			return null;
		if (Font.Load(mDevice, path, pixels) case .Ok(let font))
		{
			mFonts[new String(key)] = font;
			return font;
		}
		ReportOnce("REN0002", scope $"The font file '{path}' could not be loaded.");
		return null;
	}
}
