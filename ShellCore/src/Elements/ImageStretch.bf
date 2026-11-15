namespace Shell.Elements;

using System;

// How an image / video frame fills the element box.
enum ImageStretch
{
	case None;              // natural size at the top-left corner
	case Fill;              // stretched to the box, aspect ratio ignored
	case Uniform;           // fitted inside the box, aspect ratio kept
	case UniformToFill;     // covers the box, aspect ratio kept, overflow cropped
}
