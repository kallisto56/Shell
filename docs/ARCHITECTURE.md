# Shell and visual editor: architecture (Stage 1)

Status: the foundation described here exists as Beef code in `ShellCore/src`. Items marked **(Stage n)** are decided here
but implemented later. Nothing in this document replaces a requirement of the specification with a simpler one.

## 1. Modules and dependency rules

| Project | Purpose | Depends on |
|---|---|---|
| `Juno` (existing) | Win32 + DirectX 11 wrapper, math | corlib |
| `Freetype` (existing) | FreeType + HarfBuzz bindings | corlib |
| `JunoFramework` (existing, from the previous task) | `Application`, `Graphics` (batched 2D/3D), `Font`, `InputState`, simple debug UI | Juno, Freetype |
| **`ShellCore`** (new, this stage) | Runtime model: ids, lifecycle, reflection, bindings, Widget / Element / Blueprint / UserWidget data and contracts, styling, animation data, layout contracts, platform + simulation **interfaces**, serialization model, editor command contracts, render backend contract | corlib only |
| `ShellRuntime` (Stage 2-3) | Kernel loop, concrete systems (binding resolver, Blueprint scheduler, animation evaluator, layout, input routing), widget library | ShellCore |
| `ShellFormat` (Stage 2) | Text parser/writer, document <-> model conversion, migrations | ShellCore |
| `ShellRender` (Stage 4+) | Element renderer + `IRenderBackend` on `JunoFramework.Graphics` | ShellRuntime, JunoFramework |
| `ShellPlatformWin` (Stage 2+) | Windows implementations of the platform services | ShellCore, Juno |
| `ShellSimulation` (Stage 2+) | Virtual file system, virtual windows, fault injection | ShellCore |
| `ShellEditor` (Stage 4+) | Editor application | all of the above |
| `ShellHost` (Stage 5+) | The real shell executable | all except the editor and simulation |

Rules:
1. `ShellCore` never references `Juno`, Win32 or DirectX. Anything native is behind an interface in `Shell.Platform` or
   `Shell.Rendering`. This keeps the framework testable without a window and keeps Windows-specific code isolated.
2. Only `ShellPlatformWin` and `ShellRender` may call Juno. Only `ShellHost` and `ShellEditor` choose which environment
   (real or simulated) is plugged in; the code above them cannot tell the difference.
3. The old `Juno.Widget` / `Juno.Panel` UI of `JunoFramework` is a debug-overlay toolkit. It is not the product's Widget
   system and is not used by the shell. The namespaces differ (`Juno.*` vs `Shell.*`), so both can coexist.

Namespaces inside `ShellCore`: `Shell.Core`, `Shell.Reflection`, `Shell.Binding`, `Shell.Widgets`, `Shell.Elements`,
`Shell.Blueprints`, `Shell.Composition`, `Shell.Styling`, `Shell.Animation`, `Shell.Layout`, `Shell.Platform`,
`Shell.Simulation`, `Shell.Serialization`, `Shell.Editor`, `Shell.Rendering`; one folder per namespace.

## 2. Conventions (matching the Juno repository)

* One type per file, file name = type name, file-scoped `namespace`, tabs, braces on their own line.
* Fields `mName`, booleans `bName`, constants `cName`, statics `sName`, interfaces `IName`, enum cases PascalCase.
* `[CRepr]` only for types that cross the native boundary (none in ShellCore).
* Errors: `Result<T>` / `Result<T, EnumError>` for operations that can fail in expected ways; `DiagnosticSink` for anything
  the user must see; `Runtime.Assert` only for programmer errors. Nothing fails silently.
* Out parameters at call sites: `Foo(var x)` (project convention).

## 3. Identity, ownership, lifetime

* **`StableId`** (64-bit, 16 hex digits in files): identity of everything serializable (widgets, elements, layers, nodes,
  pins, links, definitions, tokens ...). Generated once, never reused, preserved by copy/paste only when the copy stays in
  the same document (paste elsewhere generates new ids and remaps references). `IdGenerator` is seedable for reproducible tests.
* **`Handle`** (index + generation): reference to a *live* object, never saved. `HandleTable` returns null for stale
  handles, so "the object is gone" is detectable at every use.
* **`RuntimeObject`**: base of live objects. One owner each; the owner is responsible for memory. References are handles.
  States: Created, Initialized, Active, Deactivating, Destroyed.
* **Destruction protocol**: `RequestDestroy()` marks the object and its owned children (children first) Deactivating;
  traversals skip such objects. In the Commit phase `RuntimeContext.FlushDestruction()` detaches, calls `OnDestroy`, releases
  the handle and deletes. Handles resolved before the flush still work, afterwards they return null.
* **Structural changes** (attach/detach/reparent/add child) are immediate when no traversal is active and are queued as
  `Mutation` objects otherwise (`TraversalGuard`, `MutationQueue`, applied in Commit). Mutations carry handles and
  re-validate them when applied.
* Ownership of definitions (`CompositionDefinition`, `BlueprintAsset`, `Theme` ...): the project/registry that holds them.
  Live instances never own definitions; they reference them by `StableId`.
* Native resources (textures, fonts, windows) are owned by the backend that created them and referenced from the model by
  `StableId` asset ids, so model objects can be destroyed without touching GPU state.
* **`RuntimeContext`** bundles the shared services of one running shell: ids, handle table, mutation queue, diagnostics,
  string pool, type registry, global variables, time source. Editor preview, simulation and real shell each own one.

## 4. Frame cycle (deterministic)

`UpdatePhase` order, each phase run by `IRuntimeSystem`s sorted by (order, registration):

1. **Input**: platform events -> input routing -> widget state changes and widget events (events are queued for Blueprints).
2. **Timers**: `TimeSource` update (scaled time, delta, unscaled variants), delays, scheduled work.
3. **Blueprints**: queued events run FIFO, each to completion.
4. **Animation**: controllers evaluate and write contributions (layer `Animation`); pose solvers afterwards (layer `Solver`).
5. **Bindings**: dirty bindings re-evaluate once, style rules resolve, `ContributionStack` resolves final property values.
6. **Layout**: dirty subtrees only (`Invalidation.Layout`).
7. **Commit**: `MutationQueue.Flush`, `FlushDestruction`. The only place where trees change structurally during a frame.
8. **Render**: read-only; `RenderListBuilder` produces the ordered list, the backend draws it.

Within a frame everything sees one `FrameContext` (frame index, scaled/unscaled time and delta, time scale). The simulation can
drive frames with a fake clock, so runs are reproducible.

## 5. The three systems and their contracts

### Widget (`Shell.Widgets`)
* Owns behavior and meaningful state. State lives in a `PropertyStore` laid out by the widget's `TypeDescriptor`.
* Property kinds are explicit: **State** (read-only from outside, e.g. Hovered, CaretRect), **Value** (writable, serialized),
  **Computed** (derived). Methods and events have descriptors. Widget types add typed, widget-specific members on top of the
  small base `Widget` type (Name, Enabled, Visible, Focusable, Bounds + hover/press/focus state); nothing forces identical
  properties on all widgets.
* Consumers of widget state: Element bindings, Blueprints (get/set property, call method, subscribe to event), style rules
  and animation conditions (via `WidgetStateFlags` / named bool states), the editor inspector. All of them go through
  `IPropertyHost` / `IMethodHost` / `IEventSource` and the descriptors, never through widget-specific code.
* A widget is usable without any skin: it has an (empty) `ElementTree`; visuals are optional.
* Input dispatch, focus, keyboard navigation, text-input integration: **(Stage 3)**; the hooks it needs (descriptors,
  `ITextInputClient`, state setters, invalidation) exist.

### Element (`Shell.Elements`)
* Visual only. Holds transform/opacity/visibility properties, composite mode (`None`, `IsolatedGroup`, `BackdropGroup`),
  effects, bindings, an optional visibility condition. Never holds interaction state.
* **Three separate hierarchies**: ownership (`mParent`/`mChildren`), layout (`mLayoutParent`, defaults to owner), render order
  (`mLayer` + `mZIndex`).
* **Layers**: each widget skin has `LayerDefinition`s (Underlay, Content, Overlay always present, custom ones allowed; Content is
  essential and cannot be removed). An element's layer is its own or inherited from its owner. `RenderListBuilder` renders layer by
  layer, so a child owned by the Content container can draw in the Overlay (caret, border) and underlay content (hover glow)
  draws below. Groups wrap an element and its same-layer descendants; descendants on other layers draw outside the group.
* **Conditional composition**: `mVisibleWhen` binding; hidden subtrees are skipped by layout, input and render but stay alive
  (bindings and animations keep their state). Dynamic creation/removal goes through `ElementTree` (deferred while traversing).
* Lifecycle/identity: elements have stable ids; moving an element (`Reparent`) keeps identity, bindings and animation tracks.
* Reserved: `ElementKind.Mesh` + `ISkeletonProvider`/`IPoseSolver`/`IGeometryDeformer` for rigs (not implemented).

### Blueprint (`Shell.Blueprints`)
* Authoring model: `BlueprintAsset` = variables + explicit `BlueprintInterface` (public variables, functions, events) + graphs
  (nodes with typed pins, links). Node kinds are a closed enum plus library operators by type name.
* **Events**: Start, Tick, Destroy, Custom, WidgetEvent, GlobalChanged, VariableChanged. Raised events are queued (FIFO,
  `BlueprintLimits.cMaxQueuedEvents`) and run to completion in the Blueprints phase.
* **Calls between Blueprints** use `BlueprintRef` (Self / OwnerWidget / Instance by id / Singleton by asset id), never display
  names, and are synchronous. Result is a `CallResult` with `CallStatus`: TargetMissing, NotPublic, SignatureMismatch,
  DepthExceeded, ReentrancyBlocked, Faulted. Failures are reported as diagnostics and take the node's failure exec pin;
  they never silently do nothing.
* **Re-entrancy**: an instance is never re-entered by an *event* while one of its executions runs (events are queued);
  direct recursive calls are allowed up to `cMaxCallDepth` (32). Per-execution node and loop limits abort with a diagnostic.
* **Variables**: Local (per call), Instance, Persistent (stored by a persistence service), plus **globals**
  (`GlobalVariableStore`: typed, initial values, observable). A global change notifies observers synchronously (bindings
  become dirty, event nodes are queued), the reactions run later in their phase. Example: setting `HighAlertMode` queues the
  siren Blueprint's `GlobalChanged` event and dirties every warning-lamp binding.
* **Time**: `TimeSource` exposes Time, UnscaledTime, DeltaTime, UnscaledDeltaTime as observable built-ins (bindable, readable by nodes).
* **Debugging**: `IBlueprintDebugger` (break before node, pin values, errors) is optional and null in the real shell.
* Blueprints coordinate; they do not replace the renderer, animation evaluator or widget implementation. They reach widgets
  and elements only through reflection (`IPropertyHost`, `IMethodHost`), animation only through inputs, and platform services only
  through `ServiceBroker`.

### UserWidget (`Shell.Composition`)
* Authored data model, no separate prefab type: `CompositionDefinition` = root `WidgetNodeData` + Blueprints + clips + state
  machines + exposed members. Any composition can become one; "extract" is an editor command that moves a subtree of
  `WidgetNodeData` into a new definition, replaces it by an instance node and creates `ExposedMember`s for everything the outside used.
* **Instances** are `WidgetNodeData` with `mSourceDefinition` set. They store only overrides (`OverrideEntry` = path of stable ids
  + property + value), so definition edits propagate to all instances. Multiple independent instances: each has its own state,
  Blueprint instances and animation controllers.
* **Public interface**: `ExposedMember`s forward a public name to an inner property, variable, method or event. Outer code
  only sees public names; inner structure can be reorganized freely.
* **Propagation**: editing a definition bumps `mRevision`; `CompositionRegistry.GetDependents` yields the definitions that
  contain it (transitively); live instances are rebuilt by diffing on stable ids (keep objects whose id still exists, create new,
  destroy removed), then overrides are re-applied. Overrides whose target disappeared stay stored as *orphans* and raise
  `CMP` diagnostics; they are never dropped silently.
* **Missing / cyclic dependencies**: `FindMissing`, `FindCycle` run on load and edit; an instance of a missing definition becomes a visible
  placeholder widget with an error badge; cycles are rejected at the edit that would create them.

## 6. Bindings, events, references

* **Binding** (`BindingDescriptor` saved, `Binding` live): target property of the owner <- source (`Constant`, `OwnerProperty`,
  `ParentProperty`, `WidgetProperty`, `GlobalVariable`, `BlueprintVariable`, `StyleToken`, `AnimationInput`, `TimeBuiltin`) through a
  closed converter pipeline (Not, Negate, Scale, Offset, Clamp, IsEmpty, ToText, Select, EqualsTo, GreaterThan, Coalesce) with a
  fallback value. Modes: OneWay, TwoWay, OneTime.
* **Dependency tracking**: every source is an `IObservable` (version + observers). A change only marks dependent bindings dirty;
  they re-evaluate once in the Bindings phase. Property changes also carry `Invalidation` flags (Visual, Layout, Geometry, Style,
  Structure, Text), so a change only invalidates what depends on it.
* **Events**: `EventDescriptor` + `EventDispatcher` (subscription ids, safe during dispatch, re-entrancy depth limit 16).
* **References**: saved = `StableId`; live = `Handle`; both resolve through the context, unresolved references yield diagnostics.
* **Type safety**: connections go through `TypeDescriptor`/`PropertyDescriptor`/`MethodDescriptor`/`EventDescriptor` and `ValueKind`;
  there are no unchecked string-based calls. Names appear only as part of descriptors and are validated at load/edit time.

## 7. Styling and arbitration of property writers

* Data: `DesignToken` (typed, may alias), `Theme` (tokens, fallback parent), `ComponentStyle` (per widget type, ordered
  `StyleRule`s with `StyleCondition` on state flags/named states, setters targeting widget or elements, tokens or literals).
* **One arbitration mechanism**: `PropertyLayer` order **Default < Theme < ComponentStyle < StateStyle < InstanceOverride <
  Animation < Blueprint < Solver**. Each system writes only to its own layer through `Contribution`s (blend Replace / Add / Multiply,
  weight, order); `ContributionStack.Resolve` computes the final value deterministically. Therefore animation state machines select
  authored motion, Blueprints add procedural values (layer Blueprint, cleared explicitly), rig solvers have the last word, and none of
  them fights over the same property.
* Animation split: **state machine** (`StateMachineDef`) selects/coordinates clips and blend trees from inputs (bool, number,
  trigger); **Blueprint** supplies logic and sets inputs; **controller** (`IAnimationController`) evaluates authored curves
  (`AnimationClip`/`AnimationTrack`/`Keyframe`); **solvers** (`IPoseSolver`) compute procedural deformation. Two controllers
  animating the same (object, property) is a validation error and deterministic by order at runtime.
* Window minimize/restore transitions that morph a window into its taskbar icon are an effect/animation on a *window thumbnail* element;
  the platform side provides `IWindowTracker.SetTaskbarButtonBounds` and a thumbnail resource **(Stage 5+)**.

## 8. Platform services and simulation

* Interfaces (`Shell.Platform`): `IWindowTracker`, `IMonitorService`, `IFileSystemService`, `IApplicationLauncher`,
  `IShellIntegration`, `INotificationService`, `IClipboardService`, `ITextInputService` (+ `ITextInputClient`), `IClock`, bundled in
  `PlatformServices`. Slow or fallible calls return `IOperation` (Pending / Succeeded / Cancelled / Failed, progress, cancel, error).
* `ShellPlatformWin` implements them with Win32; `ShellSimulation` implements them over virtual state
  (`IVirtualEnvironment`: virtual file system and windows, controllable clock, `FaultRule`s for delays, failures, cancellations,
  seeded so scenarios replay identically). The deletion-confirmation example runs against the virtual file system.
* **Security**: content never holds raw services. `ServiceBroker` returns a service only if the calling package's `Capability` bits
  allow it (`PermissionSet`; downloaded packages start with `None`) and reports a diagnostic otherwise. `PackageManifest` lists
  *requested* capabilities; the user grants them.
* Real-shell concerns (DPI, multi-monitor, activation, minimized windows, coexistence with normal apps, input routing, native
  window lifecycle) are covered by `MonitorInfo.mDpiScale/mWorkArea`, `TrackedWindowFlags` (including `ShellOwned`, `ToolWindow`,
  `Cloaked`) and the listener interfaces. Everything is physical pixels with explicit DPI scale; Windows 10 specifics stay inside
  `ShellPlatformWin`.
* Text: `ITextInputClient` uses UTF-16 offsets plus composition (pre-edit) text, so IMEs work; shaping is HarfBuzz (already in the
  Freetype project); layout never assumes LTR or one glyph per character.

## 9. Saved format and versioning

* Text, UTF-8, LF, no BOM, tab indentation, one statement per line, so diffs are line-local. Header
  `juno-shell <major>.<minor>`.
* Every object: type name, `id` (16 hex digits) and explicit typed fields; field order = descriptor order, children in ownership
  order, ordered collections stay ordered, sets are sorted by id. No dependence on hash-map iteration order.
* Numbers: integers decimal; floats shortest round-trip with `.` as decimal separator written/parsed by our own code (never the
  current locale); colors as four floats (lossless); strings quoted with `\"`, `\\`, `\n`, `\uXXXX` escapes; references are ids with an explicit kind.
* Shape (final grammar and kinds in section 13):

```
juno-shell 1.0
widget Button id=1a2b3c4d5e6f7081 name="OK"
{
	prop Enabled:bool = true
	prop Bounds:rect = 0 0 120 32
	bind Text:string <- global "ButtonLabel" | ToText
	skin
	{
		layer id=... name="Content" role=Content order=0 essential
		element Shape id=... layer=... { prop Size:vector2 = 120 32 }
	}
}
```
* Schema: `SchemaVersion(major, minor)`. Minor = additive (unknown fields are reported as warnings and ignored (preserving them on rewrite is not implemented yet)). Major = migration through
  `IMigration` steps on the generic `Document`/`DocumentNode` tree *before* typed loading (`MigrationRegistry` finds the chain,
  refuses files from newer majors). Typed model classes are converted by static serializers in `ShellFormat` (`ProjectSerializer`, `WidgetSerializer`, `BlueprintSerializer`, ...), so `ShellCore` stays free of any file format.

## 10. Editor contracts

* All edits are `ICommand`s executed through `CommandStack` (undo, redo, merge, groups, dirty tracking). `Selection` is by stable id.
  `IValidator` reports `Diagnostic`s (stable codes) on edit, load and export.
* The editor shares the runtime: preview = a `RuntimeContext` instantiated from the model; simulation = same plus `IVirtualEnvironment`.
  Authoring data (`*Data` / `*Asset` / `*Definition` classes) and live objects (`Widget`, `Element`, `IBlueprintInstance`) are different classes.

## 11. Dependency order of the remaining stages

1. **Stage 2**: `ShellRuntime` kernel (loop over `UpdatePhase`, system registration), `ShellFormat` (parser/writer for the grammar, typed serializers
   for all model classes, validation, migrations), `ShellPlatformWin` + `ShellSimulation` services, binding resolver over `RuntimeContext`. **Done**, see section 13.
2. **Stage 3**: input routing/focus/navigation, concrete widgets (Button, TextBox with selection, caret, IME), method/event invocation glue.
3. Then (not in the given stages yet): element renderer + render backend on Juno, layout engine, style/animation evaluators, Blueprint VM,
   UserWidget instantiation/propagation, editor, shell components.

## 12. Decisions made where the specification was open

1. 64-bit random ids with 16-hex text form (short, diff-friendly); handles are generation-checked indices.
2. `ShellCore` has no Juno dependency; it uses its own `RectF`/`Thickness`/`Value` types.
3. Reflection is explicit registration with descriptors (no code generation); descriptors drive inspector, bindings, Blueprints, serialization.
4. Closed converter set for bindings; anything more is a Blueprint.
5. Layers are per widget skin, three always present, Content essential.
6. Blueprint events are queued; function calls are synchronous with depth limit; failures always produce a result status and a diagnostic.
7. One writer arbitration stack (`PropertyLayer`) for styles, animation, Blueprints and solvers.
8. Overrides are addressed by chains of stable ids and survive missing targets as orphans.
9. Platform calls that can take time return `IOperation`; the simulation controls completion.
10. Format is our own deterministic text grammar rather than JSON/TOML, to guarantee ordering, typed values and locale-independent numbers.

## 13. Stage 2 (core runtime, platform layer, serialization): what exists

### Runtime (`ShellRuntime`)
* `ShellKernel.Tick(unscaledDelta)` runs the eight phases in order. Time is injected (real clock or scripted), delta is clamped to 0.25 s, time scale and pause are
  supported. Input, Animation, Bindings, Layout and Render run with the `TraversalGuard` entered (tree changes are queued); Commit flushes the
  `MutationQueue` and then `FlushDestruction`. `RuntimeSystemList` orders systems by (phase, order, registration).
* `RuntimeBindingResolver` resolves Constant, TimeBuiltin, GlobalVariable, StyleToken (`IThemeProvider`), WidgetProperty (by stable id), OwnerProperty and
  ParentProperty; Blueprint variables and animation inputs plug in through `Register(kind, provider)`. Every failure is a diagnostic (`BND....`).
  `BindingSystem` (Bindings phase) refreshes dirty bindings once per frame and writes the converted values into the bound properties.
* `RuntimeContext` now indexes live objects by stable id (`FindByStableId`). Ids duplicated by instances of one UserWidget are handled by the scoped lookup of Stage 3.

### Format (`ShellFormat`)
* Grammar (final for schema 1.0), one statement per line, tab indentation, LF:

```
juno-shell 1.0
Type 0123456789abcdef            node header: type name + stable id ('-' = none)
{
	Name:string = "text"           field: name ':' kind '=' payload
	children[                      group of child nodes
		Type ...
	]
}
```
  Kinds and payloads: `none`; `bool` true|false; `int` -?digits; `float` -?digits[.digits][e[+-]digits] | nan | inf | -inf; `string` in double quotes
  with the escapes \" \\ \n \r \t \uXXXX; `enum` identifier (case name); `id` 16 hex digits or `-`; `vector2` x y; `color` r g b a; `rect` x y w h. Colors are stored as floats
  (lossless), not as 8-bit hex.
* Numbers: validated by our grammar first, then converted with Beef's `Parse`/`ToString`, which are culture-neutral (no regional separators); text that
  does not match the grammar (for example `1,5`) is rejected with `SER0109`. Verify round-trip equality of floats in your test suite (assumption: Beef's shortest
  `ToString` round-trips).
* Determinism: field and group order come from the model (descriptor/list order), never from hash iteration; optional values equal to their default are
  omitted; `ProjectFile.SaveToText` of an unchanged project is byte-identical. Saving writes `<file>.tmp` and then replaces the target.
* `TextReader` -> `Document`/`DocumentNode` -> `MigrationRegistry.MigrateToCurrent` -> `ProjectSerializer.Read` -> `ProjectValidator`. Errors carry stable codes
  and line numbers (`SER01xx` syntax, `SER02xx` typed access, `SER03xx` writing, `SER04xx` structure) and parsing stops at the first syntax error.
* Typed serializers cover the project manifest, globals, themes/tokens, component styles/rules/setters, shared Blueprints (variables, interface, graphs,
  nodes, pins, links), compositions (widgets, overrides, event hooks, Blueprint attachments, skins with layers and elements, bindings and converters,
  effects), animation clips/tracks/keys/events, state machines (inputs, states, transitions, conditions, blend trees) and exposed members.
* `ProjectValidator` (`VAL....`): duplicate or missing ids, missing/cyclic UserWidget definitions, missing themes/styles/Blueprints, layers (Content layer
  required), Blueprint link validity (pins exist, direction, exec vs data, equal value types), exposed member targets, animation track targets, state machine
  references, duplicate global names.

### Platform
* `ShellSimulation`: `VirtualEnvironment` bundles `VirtualClock`, `VirtualFileSystem` (in-memory, case-insensitive, recycle bin), `VirtualWindowManager`,
  `VirtualMonitorService`, `SimulatedApplicationLauncher`, `SimulatedShellIntegration` (power actions are recorded, not executed), clipboard and notifications.
  `OperationScheduler` completes `SimulatedOperation`s when the simulated clock reaches their due time; `FaultInjector` applies `FaultRule`s (delay, fail, cancel,
  probability with a seeded generator, `*` patterns). Effects happen at completion, so cancelling a pending operation changes nothing. Snapshots/Reset restore
  file system, windows and clock.
* `ShellPlatformWin`: `WinClock`, `WinMonitorService` (per-monitor DPI, appbar work-area reservation), `WinWindowTracker` (EnumWindows polling + diff, cloaked/tool/owned
  filtering, ShellOwned flag), `WinFileSystemService` (list, create, rename; copy/move/delete via the shell file operation without prompts and without overwriting;
  recycle or permanent delete), `WinApplicationLauncher` (ShellExecute, Start menu scan), `WinShellIntegration` (known folders, open, properties, recycle bin, shutdown,
  lock, sign out), `WinClipboardService`, `WinNotificationService` (in-process notification center). `WindowsPlatformSystem` polls windows and prunes operations in the Input phase.
* Not in this stage: `ITextInputService` implementation (Stage 3), worker-thread execution of long file operations, persistence service, intercepting other
  applications' toast notifications.

### Revisions of Stage 1 made in Stage 2
* `IDocumentSerializable` was removed: model classes are converted by static serializers in `ShellFormat`.
* `Mutation` objects replace delegate-based deferred actions in `MutationQueue` (no closure capture needed; handles are re-validated when applied).
* `RuntimeContext` gained `TimeSource` access and the stable-id index; `ShellProject` (root model) and `IThemeProvider` were added to `ShellCore`.
* Operation / window snapshot lifetime rules were written into `IOperation` and `IWindowTracker`.

## 14. Stage 3 (widget runtime): what exists

Concrete widgets live in `ShellRuntime` (namespace `Shell.Runtime`); the base `Widget`, descriptors, input event types and contracts live in `ShellCore`.

### Declaring widgets
* `WidgetTypeBuilder` declares a widget type once, statically: `AddValue` (writable, serialized, bindable), `AddState` (read-only from outside, written by the widget with
  `SetState`), `AddComputed` (derived, the widget overrides `GetProperty` and notifies `Observe(property).NotifyChanged()`), `AddEvent(...).Param(...)`, `AddMethod(...).Param(...).Returns(...)`.
  `TypeDescriptor.OverrideDefault` changes the default of an inherited property (a Button is focusable by default).
* Built-in descriptors are process-wide singletons shared by every `RuntimeContext` (`TypeRegistry.Register(type, sink, ownsType: false)`), so the editor preview, the simulation and the
  real shell can all hold widgets at once. `WidgetLibrary.RegisterTypes(context)` registers Widget, Element, Container, Button, TextBox.
* `Widget.Invoke` validates every call centrally (known method, argument count, argument types, parameter defaults, Int accepted for Float) before `OnInvokeMethod` runs.

### How public state reaches Elements and Blueprints
* **Element bindings**: `BindingSystem.AddElementBinding / AddWidgetBinding / SetCondition` create the runtime `Binding`s. Sources are `IObservable`s on the widget's `PropertyStore`;
  a change marks the binding dirty and the Bindings phase writes the converted value. Computed properties are observable too. When a widget or element is destroyed its bindings are removed;
  when a binding's *source* object is destroyed it is detached, re-evaluated (diagnostic + fallback value). Visibility conditions drive `Element.bConditionVisible`.
* **Blueprints**: through `IPropertyHost` / `IMethodHost` / `IEventSource` and the descriptors. `WidgetRuntime.ForwardToBlueprints(widget, event)` subscribes a `QueuedEventListener`
  that copies the event (string arguments retained in the string pool) into the `EventQueue`; the Blueprint host takes the queue in the Blueprints phase (FIFO, bounded, run to completion).
  Widgets raise events immediately; only Blueprint subscribers are queued.
* **Style / animation**: `Widget.mStateFlags` is derived from the State properties (Hovered, Pressed, Focused, KeyboardFocused, effective Enabled).
* A widget without a skin is fully functional; visuals are optional.

### Input
* Platform -> `InputEventQueue` (any time) -> `InputRouter` (Input phase). Pointer: hover chain with `Hovered` on the target and its ancestors and Entered/Exited events, automatic capture on
  press (move/up go to the pressed widget until all buttons are up), focus follows the press, tunnel (`OnPreviewPointer`, root to target) then bubble (`OnPointerDown/Up/Move/Wheel`, target to root),
  cursor selection (`GetDefaultCursor`, `Cursor` property). Keyboard: tunnel/bubble to the focused widget (root without focus); unhandled Tab / Shift+Tab / arrows navigate. Text: committed text to the focused widget.
  Disabled widgets block hit testing but receive no callbacks; hidden ones are skipped.
* `FocusManager`: focus rules (alive, Focusable, effectively enabled and visible), reasons (Programmatic / Pointer / Keyboard; the keyboard ring only for Keyboard), Tab order by `TabIndex` then tree order
  (negative = skipped), focus scopes (`FocusScope` widgets keep Tab inside), spatial arrow navigation, focus cleared when the widget is destroyed / hidden / disabled, text input service attach/detach.
* `IObjectDestroyListener` (new, `RuntimeContext.AddDestroyListener`) lets focus, capture, hover and binding lists drop references before an object is freed.

### Widgets
* `ContainerWidget`: grouping, transparent to the pointer unless `BlocksInput`.
* `Button`: Text, ClickMode (Release | Press), event Clicked, method Click. Pressed only while the pointer is inside; Space clicks on release, Enter on press.
* `TextBox`: Text, PlaceholderText, IsReadOnly, AcceptsReturn, AcceptsTab, MaxLength, SelectionStart / SelectionLength / CaretIndex (UTF-16 units), state CaretRect / IsComposing / CompositionText, computed HasSelection /
  SelectedText / TextLength, events TextChanged / SelectionChanged / Submitted, methods SelectAll / Select / Clear / InsertText / Cut / Copy / Paste / SetCaret.
  Caret movement, deletion and selection work on grapheme clusters (`ITextSegmenter`, pragmatic `SimpleTextSegmenter`), words with Ctrl, Home/End, multi-line Up/Down with a desired column, Shift extends, mouse
  click / drag / double click (word) / triple click (line), clipboard (Ctrl+C/X/V, Ctrl+Insert, Shift+Insert/Delete), newline normalization, MaxLength in code points, tabbing in selects all.
  Geometry comes from `ITextMetrics` (to be supplied by the Text element; `FallbackTextMetrics` until then, bidirectional text is treated as LTR there).
  IME: the widget is an `ITextInputClient` (composition text kept apart from Text, committed through `ReplaceText`), attached to `ITextInputService` while focused.

### Text input subsystem
* `ShellPlatformWin`: `WinInputBridge` (Win32 messages -> input events: mouse with click counting and capture, keys with left/right modifiers and repeat flag, WM_CHAR with surrogate pairs, cursor,
  focus loss cancels pointer / composition) and `WinTextInputService` (IMM32: composition string and cursor, result string, candidate window at the caret, composition window hidden because the TextBox draws it).
* `ShellSimulation`: `SimulatedTextInputService` (`SimulateComposition / SimulateCommit / SimulateCancel`) is part of `VirtualEnvironment`, so IME flows can be designed and tested in the editor.

### Core revisions made in Stage 3
* `StringPool` is reference counted: `Intern` is permanent, `InternTransient` is collectible. `PropertyStore` retains/releases string values and `ShellKernel` calls `CollectGarbage()` in Commit
  (needed because a text box creates a new string per edit).
* `Widget` gained input hooks, hit testing (`FindTargetAt`), effective enabled/visible, computed `IsEffectivelyEnabled`, state setters, validated `Invoke`, `mBindings`; `WidgetTypes` gained TabIndex, HitTestVisible,
  FocusScope, Cursor and Focus/Blur methods; `IBindingResolver.GetLastSourceObject`; `Binding.bIsCondition`; `RuntimeContext.mWidgetHost` / destroy listeners.
* `BindingSystem` now takes the context and handles lifetimes (see above); `KeyCode` of the Juno framework was copied as `Shell.Input.Key` so `ShellCore` has no dependency on it.

### Verification without a window
`WidgetSmokeTests.Run(sink)` (ShellRuntime/Testing) drives the real kernel with scripted input and checks button pointer/keyboard behavior, disabled widgets, Tab / Shift+Tab / arrow navigation, text editing
(clusters, selection, word movement), IME composition and commit, and method/property validation.

### Known limits (deliberate)
* No undo/redo in TextBox yet (it belongs with the editor's command infrastructure); no password mode; no spell check.
* Hit testing is by widget bounds (no clip regions or transforms yet); layout is by `Bounds` only.
* `SimpleTextSegmenter` is not full UAX #29; bidi caret movement and wrapping need the Text element's metrics.
* The widget event queue exists, but the Blueprint host that drains it is a later stage.
