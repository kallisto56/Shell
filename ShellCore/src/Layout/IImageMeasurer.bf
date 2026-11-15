namespace Shell.Layout;

using System;
using Shell.Core;

// Natural pixel size of an image or video source. (0, 0) when the source is unknown or not loaded.
interface IImageMeasurer
{
	PointF GetSourceSize(StringView source);
}
