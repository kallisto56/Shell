# Juno application layer

Copy `src/bf/*` next to your existing Juno Beef sources (namespace `Juno`) and add the **Freetype** project
(FreeType + HarfBuzz wrapper) as a dependency of the project. The demo is `demo/Program.bf`.

## Layout

| Folder | Contents |
|---|---|
| `Core` | `Rect`, `Insets`, `Colors` (named colors, packing helpers) |
| `Input` | `KeyCode`, `MouseButton`, `KeyModifiers`, `CursorKind`, event args, `InputState` (polling) |
| `Resources` | `Texture2D`, `RenderTarget`, `ShaderProgram`, `Mesh`, `ConstantBuffer`, `Vertex`, `VertexLayout`, `JunoLog` |
| `Graphics` | `Graphics`, `PushBuffer`, `GraphicsScope`, enums (`BlendMode`, `DepthMode`, `SamplerKind`, `TextAlign`) |
| `Fonts` | `Font` (FreeType + HarfBuzz), `FontPage` (atlas), `TextLayout` |
| `UI` | `Widget`, `WidgetRoot`, `Anchor`, `Panel`, `Label`, `Button`, `WidgetStyle` |
| `Application` | `Application`, `ApplicationWindow` |

## Shader conventions (HLSL, entry points `VSMain` / `PSMain`)

* `b0` FrameConstants `{ row_major float4x4 gViewProjection; float gTime; float gDeltaTime; float2 gViewportSize; }`
* `b1` ObjectConstants `{ row_major float4x4 gWorld; float4 gTint; }`
* `b2..b7` user buffers: `Graphics.SetConstantBuffer(0..5, buffer)`
* `t0..t3` textures: `Graphics.SetTexture(tex, slot)`; `s0` sampler: `Graphics.SetSampler(kind)`
* Default vertex: `POSITION float3`, `TEXCOORD float2`, `COLOR R8G8B8A8_UNorm` (24 bytes). Other vertex formats:
  build a `VertexLayout` and pass it to `Application.CreateShader`.
* Default 2D projection is pixel space, origin top-left. `SetCamera(view, projection)` for 3D (row-vector convention).

## Things to check when you compile (I could not)

* `Color` in `Math/Color.bf` is declared as `namespace Color;`. `Colors.bf` and the rest assume `namespace Juno;`.
* APIs I relied on from your Math library: `Vector2/3(x, y[, z])` with `mX/mY/mZ`, `Matrix4x4.sIdentity`,
  `CreateLookAt/CreatePerspectiveFieldOfView/CreateRotationX/Y/CreateScale/CreateTranslation`, `operator *`,
  `Matrix3x2` members `m11..m32` and `CreateTranslation/CreateScale/CreateRotation(angle, center)`.
* Beef library APIs: `Stopwatch.ElapsedMicroseconds`, `Event<delegate ...>` invocation, `StringView.IndexOf(char8, int)`.
* `Font.GetGlyph` loads with `.FT_LOAD_RENDER` and checks `pixel_mode == 2` (gray); adapt if your enum names differ.
* `PushBuffer.CanFit` is `<=` (exact fit allowed) instead of `<`.
* Text: line wrapping is greedy at spaces for left-to-right paragraphs. HarfBuzz shapes RTL runs correctly,
  but there is no bidi reordering of mixed-direction text.
