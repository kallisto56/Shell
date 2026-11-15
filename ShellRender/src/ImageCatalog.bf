namespace Shell.Render;

using System;
using System.Collections;
using System.IO;
using Juno;
using Shell.Core;
using Shell.Layout;

// Images and video frames by source name.
//   * a registered texture ("rt:desktop-wallpaper") is looked up first (not owned),
//   * otherwise Source is a file path, relative to mAssetRoot, loaded once and cached (owned; a failed load is remembered and reported once).
// Also answers the layout engine's question for the natural size of a source.
class ImageCatalog : IImageMeasurer
{
	Device* mDevice;
	DiagnosticSink mSink;
	public String mAssetRoot = new .() ~ delete _;
	Dictionary<String, Texture2D> mLoaded = new .() ~ DeleteDictionaryAndKeys!(_);     // values owned (null = failed)
	Dictionary<String, Texture2D> mRegistered = new .() ~ DeleteDictionaryAndKeys!(_);  // values not owned
	Dictionary<String, IVideoSource> mVideos = new .() ~ DeleteDictionaryAndKeys!(_);   // values not owned

	public this(Device* device, DiagnosticSink sink)
	{
		mDevice = device;
		mSink = sink;
	}

	public ~this()
	{
		for (let entry in mLoaded)
			delete entry.value;
	}

	public void RegisterTexture(StringView name, Texture2D texture)
	{
		let key = scope String(name);
		if (mRegistered.GetAndRemove(key) case .Ok(let old))
			delete old.key;
		mRegistered[new String(name)] = texture;
	}

	public void RegisterVideo(StringView name, IVideoSource video)
	{
		let key = scope String(name);
		if (mVideos.GetAndRemove(key) case .Ok(let old))
			delete old.key;
		mVideos[new String(name)] = video;
	}

	public Texture2D Get(StringView source)
	{
		if (source.IsEmpty)
			return null;
		let key = scope String(source);
		if (mRegistered.TryGetValue(key, let registered))
			return registered;
		if (mLoaded.TryGetValue(key, let loaded))
			return loaded;

		let path = scope String();
		if (Path.IsPathRooted(source) || mAssetRoot.IsEmpty)
			path.Set(source);
		else
			Path.InternalCombine(path, mAssetRoot, source);

		Texture2D texture = null;
		if (Texture2D.FromFile(mDevice, path) case .Ok(let created))
			texture = created;
		else if (mSink != null)
			mSink.Warning("REN0003", scope $"The image '{path}' could not be loaded.");
		mLoaded[new String(source)] = texture;
		return texture;
	}

	public Texture2D GetVideoFrame(StringView source, double deltaSeconds, bool playing, bool looping)
	{
		let key = scope String(source);
		if (mVideos.TryGetValue(key, let video))
		{
			video.Update(deltaSeconds, playing, looping);
			return video.GetFrame();
		}
		return null;
	}

	public PointF GetSourceSize(StringView source)
	{
		var texture = Get(source);
		if (texture == null)
		{
			let key = scope String(source);
			if (mVideos.TryGetValue(key, let video))
				texture = video.GetFrame();
		}
		return (texture != null) ? PointF((float)texture.mWidth, (float)texture.mHeight) : default;
	}
}
