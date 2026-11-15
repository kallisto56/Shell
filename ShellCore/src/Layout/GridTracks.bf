namespace Shell.Layout;

using System;
using System.Collections;

// Grid row / column definitions as text: comma separated tracks, each "120" (pixels), "auto" or "*" / "2*" (weight).
// Empty text = one star track. Malformed tokens become "auto" and make Parse return false (reported by the caller).
static class GridTracks
{
	static public bool Parse(StringView text, List<GridTrack> output)
	{
		bool bOk = true;
		if (text.IsEmpty)
		{
			output.Add(GridTrack() { mKind = .Star, mValue = 1 });
			return true;
		}

		for (let raw in text.Split(','))
		{
			var token = StringView(raw)..Trim();
			GridTrack track = default;
			if (token == "auto" || token == "Auto")
			{
				track.mKind = .Auto;
			}
			else if (token.EndsWith('*'))
			{
				track.mKind = .Star;
				track.mValue = 1;
				let weight = token.Substring(0, token.Length - 1);
				if (!weight.IsEmpty)
				{
					if (float.Parse(weight) case .Ok(let value))
						track.mValue = value;
					else
						bOk = false;
				}
			}
			else if (float.Parse(token) case .Ok(let value))
			{
				track.mKind = .Fixed;
				track.mValue = Math.Max(value, 0);
			}
			else
			{
				track.mKind = .Auto;
				bOk = false;
			}
			output.Add(track);
		}
		return bOk;
	}
}
