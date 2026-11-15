# Beef conventions for this project (collected from reviews)

* Never use Beef keywords as identifiers (`function`, `box`, `scope`, `params`, ...); prefix or rename.
* Clear owned lists with `.ClearAndDeleteItems()`, not `DeleteAndClearItems`.
* Call methods with `out` parameters as `Foo(var x)`; never inside an `if` condition (declare the variable first).
* Parsing numbers returns `Result<T>`.
* Pass const-size arrays with `ref` when the callee writes to them.
* `StringView` is a view into `char8*`: it does not own memory and must not outlive its source.
* Use the Beef source (github.com/beefytech/Beef) and docs (beeflang.org/docs) when unsure about corlib behavior.
* Shell may depend on Juno: use Juno's `Rect`, `Insets`, `Vector2`, `Matrix3x2`, `Color`, `Graphics`, `Font`, `Texture2D`, `RenderTarget` instead of defining equivalents.
