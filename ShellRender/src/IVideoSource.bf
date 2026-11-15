namespace Shell.Render;

using System;
using Juno;

// A decoded video stream as seen by the renderer. Implemented by the media layer (Media Foundation, ...); the renderer only needs the
// current frame as a texture. Registered under a name that Video elements use as their Source.
interface IVideoSource
{
	void Update(double deltaSeconds, bool playing, bool looping);
	Texture2D GetFrame();           // null until the first frame is available
}
