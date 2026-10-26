# Progress

Oracle: `dev/port/oracle/src/progress.tsx` (manifest `source_sha` e012e1f7e6e66d11, tier `radix_stateful`), wrapping `ProgressPrimitive.Root` / `ProgressPrimitive.Indicator` from `radix-ui` 1.7.0 -> `@radix-ui/react-progress` 1.1.17 (`dev/react-shadcn-catalog/node_modules/@radix-ui/react-progress/dist/index.mjs`, cited below as `progress.mjs:<line>`). React DOM 19.3.0.

Key oracle fact (progress.tsx): shadcn destructures `value` out of the props and does NOT pass it to `ProgressPrimitive.Root` (`{...props}` no longer contains it). Radix therefore always sees `value: valueProp = null` (progress.mjs:19), so the Root and the Indicator are ALWAYS in the Radix indeterminate state: `data-state="indeterminate"`, no `aria-valuenow`, no `aria-valuetext`, no `data-value`, whatever `value` the caller passes. `value` only drives the Indicator's inline `transform`. The port reproduces this exactly (it is the oracle DOM, not a bug to fix).

## API

One export, one Ruby class. The Indicator is not exported by shadcn; it is rendered internally (no Ruby class for callers).

```ruby
Chadcn::Progress.new(
  value: nil,      # Numeric or nil; only used for the Indicator transform (progress.tsx `value || 0`)
  max: nil,        # forwarded to Radix Root via ...props; valid iff Numeric, not NaN, > 0 (progress.mjs:80-82), else 100 (DEFAULT_MAX, progress.mjs:11, 27)
  class: nil,      # merged last into the Root classes through cn (tailwind_merge), caller wins
  **attrs          # id, aria: {}, data: {}, style, role overrides... pass through to the Root div (progress.mjs:44 spreads progressProps after Radix's attrs, so caller attrs win)
)
```

- `value:` is never validated and never reaches any attribute other than the Indicator `style`. Accepted: any Numeric (Integer/Float, negative, above max) or `nil`/`false`. Falsy (`nil`, `false`, `0`) means 0 (`value || 0`; note JS also treats `0` as falsy, the result is the same `-100%`).
- `max:` only affects `aria-valuemax` and `data-max` (Root) and `data-max` (Indicator, through context, progress.mjs:59-61). Only Numeric values count, exactly like Radix `isNumber` (`typeof === "number"`): `max: "50"` (String) -> 100. `max: 0`, negative, NaN -> 100 (Radix additionally logs `console.error`, progress.mjs:24-26; the port does not log). `max:` does not change the transform (shadcn hardcodes `100 - value`).
- `getValueLabel`: not offered (a JS function; and in shadcn it is a no-op because `value` never reaches Radix, so `valueLabel` is always `undefined`, progress.mjs:32). See Deviations.
- `as_child:` is not offered. See Deviations.
- Events: none. Radix Progress has no handlers, no callbacks, no `on*Change` (progress.mjs:14-67).
- `ref` has no equivalent.

## Structure

DOM (server-rendered, final; nothing is set by Stimulus):

```html
<div aria-valuemax="100" aria-valuemin="0" role="progressbar" data-state="indeterminate" data-max="100"
     data-slot="progress" class="relative h-2 w-full overflow-hidden rounded-full bg-primary/20">
  <div data-state="indeterminate" data-max="100" data-slot="progress-indicator"
       class="h-full w-full flex-1 bg-primary transition-all" style="transform: translateX(-87%);"></div>
</div>
```

Part `Progress` (Radix Root, `data-slot="progress"`), progress.mjs:33-47 + progress.tsx:
- tag `div` (`Primitive.div`).
- Attributes in Radix order: `aria-valuemax="<max>"`, `aria-valuemin="0"`, `role="progressbar"`, `data-state="indeterminate"` (`getProgressState(null, max)`, progress.mjs:72-74), `data-max="<max>"`, then shadcn's `data-slot="progress"`, `class`, then caller attrs. Absent (because value is always null at the Radix level): `aria-valuenow` (progress.mjs:38 `void 0`), `aria-valuetext` (progress.mjs:32, 39), `data-value` (progress.mjs:42 `value ?? void 0`).
- `data-state` is never `loading` or `complete` in the shadcn component, including `value: 100` (the `complete` branch is unreachable because Radix receives `null`).
- Number formatting for `max` (`aria-valuemax`, `data-max`): JS `String(number)`; an integer-valued Float renders without `.0` (`max: 50.0` -> `"50"`), other Floats use the shortest round-trip form (`"50.5"`).
- Classes verbatim from progress.tsx: `relative h-2 w-full overflow-hidden rounded-full bg-primary/20`, then `class:` through `cn`.
- Not focusable: no `tabindex` (a `div`), so Tab skips it.

Indicator (Radix `ProgressIndicator`, `data-slot="progress-indicator"`), progress.mjs:51-66 + progress.tsx:
- tag `div`, only child of the Root, no children of its own.
- Attributes: `data-state="indeterminate"`, `data-max="<max>"` (same `max` as the Root), `data-slot="progress-indicator"`, `class`, `style`. No `data-value`. No caller attrs reach it (shadcn passes none).
- Classes verbatim, no caller merge: `h-full w-full flex-1 bg-primary transition-all`.
- `style`: shadcn `{ transform: \`translateX(-${100 - (value || 0)}%)\` }`, set by React DOM through the CSSOM (`element.style.transform = ...`), so the serialized attribute is `transform: translateX(-<n>%);` with `<n> = 100 - (value || 0)` formatted as JS `String(number)`:
  - `nil`/`0` -> `translateX(-100%)`; `13` -> `translateX(-87%)`; `66` -> `translateX(-34%)`; `100` -> `translateX(-0%)` (literally `-0%`); `33.3` -> `translateX(-66.7%)` (IEEE `100 - 33.3`, identical in Ruby and JS; print without trailing `.0` when integer-valued); `12.5` -> `translateX(-87.5%)`; `-10` -> `translateX(-110%)`.
  - `value > 100` -> the string becomes `translateX(--<n>%)` (e.g. `150` -> `translateX(--50%)`), which is an invalid `transform`; the CSSOM drops it, so React leaves the Indicator without a `transform` declaration (no `style` attribute when nothing else is set). The port must emit no `style` attribute in that case rather than the invalid string. The `value-over-max` scenario pins the oracle DOM; if the runner shows React keeps an empty `style=""`, match that.

Ids: none generated (only a caller `id:`, e.g. for `aria-labelledby` from a label element).

Server vs Stimulus: the server renders everything. There is no `chadcn--progress` controller and no `data-controller` attribute: Radix Progress has no effects, listeners, timers or state of its own (progress.mjs has no `useEffect`/`useState`/handler). A value change in React is a re-render; in the port it is a server re-render (Turbo Stream replace or morph). With morphing, the Indicator element is kept and its `style` updated in place, so the `transition-all` class animates the transform exactly like the React re-render in `progress-demo`.

## Behavior

States (Radix `getProgressState`, progress.mjs:72-74): `indeterminate | loading | complete`. In shadcn's Progress only `indeterminate` is reachable (value not forwarded, see top note); the port renders it always and never computes the other two.

Transitions: none client-side. The only visual change is the Indicator transform when the caller re-renders with a new `value`; `transition-all` (default Tailwind duration 150ms, `--default-transition-timing-function`) animates it. `progress-demo` uses a React `setTimeout(500)` to go from 13 to 66; that timer belongs to the demo, not to the component, and is not ported.

Keyboard: none (no handlers in progress.mjs; Root is a non-focusable `div`). Focus: never focused; Tab moves past it (scenario `focus-order__not-focusable`). Pointer: none. Timers: none. Dismissal, scroll lock, Presence, positioning, direction: none (Radix Progress does not read `dir`).

Primitives composed: none (the radix-stimulus family table lists progress under Boolean/value, but `form-bubble-input` does not apply: Radix Progress renders no input).

## Dependencies

None. Progress renders no other `Chadcn` component and no icon (manifest `icons: []`, `registry_dependencies: []`). Scenarios use raw `_div` / `_span` / `_button` nodes only as neutral wrappers, labels and focus neighbours.

## Deviations

API only (no DOM or class difference). Entry written to `dev/port/deviations/progress.json`:

- `as_child:` not supported. Radix Root is a `Primitive.div` that accepts `asChild`, but shadcn always renders `ProgressPrimitive.Indicator` as the Root's only child, so Radix `Slot` would merge the progressbar attributes onto the Indicator div and drop the track element; no registry example uses it.
- `getValueLabel` not supported. It is a JS callback (not expressible as a kwarg), and in shadcn it has no observable effect because `value` is never forwarded to Radix (`valueLabel` is always `undefined`, progress.mjs:32).

```json
{ "reason": "API-only: shadcn Progress always renders the Indicator as the Root's only child (Radix asChild would merge the progressbar onto the indicator), and getValueLabel is a JS callback that is a no-op in shadcn because value never reaches Radix", "allow_tokens": [], "allow_missing_tokens": [], "api": ["Progress: as_child not supported", "Progress: getValueLabel not supported (no-op in shadcn)"] }
```
