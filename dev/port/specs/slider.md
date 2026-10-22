# Slider

Oracle: `gems/chadcn/dev/port/oracle/src/slider.tsx` (manifest `source_sha` 6a531f6182de6efe, tier `radix_stateful`), wrapping `SliderPrimitive.Root` / `Track` / `Range` / `Thumb` from `radix-ui` 1.7.0 -> `@radix-ui/react-slider` 1.5.0 (`gems/chadcn/dev/react-shadcn-catalog/node_modules/@radix-ui/react-slider/dist/index.mjs`, cited below as `slider.mjs:<line>`). Helpers read from source: `@radix-ui/number` (`clamp`), `react-use-controllable-state` 1.2.6 (`ucs.mjs`), `react-use-size` (`size.mjs`), `react-direction` (`dir.mjs`), `react-collection` (`collection.mjs`), `react-slot` (`slot.mjs`). React 19. Registry examples: `slider-demo` and `field-slider` (fetched from `https://ui.shadcn.com/r/styles/new-york-v4/<name>.json`); the registry item has no `meta.links`.

## API

One export (`Slider`), one Ruby class. Track, Range and Thumb are not exported by shadcn; they are rendered internally (no Ruby classes for callers).

```ruby
Components::V2::Slider.new(
  default_value: nil,               # Array<Numeric> | nil  uncontrolled initial values (Radix default [min], slider.mjs:52)
  value: nil,                       # Array<Numeric> | nil  controlled values (controlled iff not nil, ucs.mjs:20)
  min: 0,                           # slider.tsx `min = 0` (also Radix default, slider.mjs:45)
  max: 100,                         # slider.tsx `max = 100` (slider.mjs:46)
  step: 1,                          # slider.mjs:47
  orientation: "horizontal",        # "horizontal" | "vertical" (strings or symbols, shadcn-port R4), slider.mjs:48
  disabled: false,                  # slider.mjs:49
  inverted: false,                  # slider.mjs:58
  min_steps_between_thumbs: 0,      # slider.mjs:50
  preserve_thumb_order: false,      # slider.mjs:51
  name: nil,                        # bubble inputs only (slider.mjs:460), never on the root
  form: nil,                        # bubble input `form` attribute + form-control detection (slider.mjs:85, 458, 585)
  dir: nil,                         # "ltr" | "rtl" | nil; horizontal only reads it (slider.mjs:207, 218): use_direction(dir) via Components::V2::Direction::Consumer
  class: nil,                       # merged last into the Root classes through cn (tailwind_merge), caller wins
  **attrs                           # id, aria: {}, data: {}, aria-label, style, ... pass through to the Root span
)
```

- Thumb count, verbatim from slider.tsx `_values`: `value` if it is an Array, else `default_value` if it is an Array, else `[min, max]`. One Thumb per entry. NOTE the shadcn quirk: with neither `value:` nor `default_value:` shadcn renders TWO thumbs while Radix holds ONE value (`[min]`, slider.mjs:52; shadcn passes `defaultValue={undefined}` so the destructuring default applies), so the second thumb has no value and is hidden (see Structure). The port must reproduce it.
- Radix value state = `value` (controlled) or `default_value || [min]` (uncontrolled). Initial values are NOT clamped or snapped (slider.mjs:69-71 stores them as given); only updates are.
- `value:` (controlled): the server renders that state; user input does NOT change the DOM, it only dispatches `shadcn--slider:value-change` (ucs.mjs:38-42: `onChange` only when the computed array differs from `prop`, i.e. when `updateValues` did not return `prevValues`) and still moves focus to the affected thumb (focus is done inside Radix's `onChange`, slider.mjs:72-80). Callers re-render the next state from the server.
- `default_value:` (uncontrolled): the controller owns state after connect.
- Strings and symbols for `orientation:`/`dir:` (`:vertical`, `"vertical"`). Numbers are Integer or Float; rendered with JS `Number#toString` semantics (`50`, not `50.0`; `0.6`, `33.333333333333336`), see Structure.
- Events (dispatched from the Root span, `bubbles: true`, NOT cancelable; Radix `onValueChange`/`onValueCommit` are not preventable):
  - `shadcn--slider:value-change`, `detail: { value: [Number...] }` (Radix `onValueChange`, slider.mjs:79). Uncontrolled: after the DOM is updated (useUncontrolledState effect, ucs.mjs:62-67); controlled: instead of updating.
  - `shadcn--slider:value-commit`, `detail: { value: [Number...] }` (Radix `onValueCommit`): keyboard (Home/End/step keys) when the values changed (slider.mjs:120, 163, 169, 186); pointer at pointerup when the values differ from those at pointerdown (slider.mjs:101-104, String comparison). At slide end Radix passes the values of the last render (slider.mjs:103 `onValueCommit(values)`), i.e. the current values; the port dispatches the current values.
- `as_child:` is NOT offered: see Deviations.
- `ref`, `onValueChange`, `onValueCommit` callbacks: no Ruby equivalent beyond the events above. `onPointerDown`/`onKeyDown` etc. are plain DOM listeners via `data: { action: }`; Radix runs the consumer handler first and skips its own if `event.defaultPrevented` (`composeEventHandlers`, slider.mjs:148, 356, 368, 378, 382), so the controller checks `defaultPrevented`.

## Structure

Server-rendered DOM for `Slider.new(default_value: [25, 75])` horizontal LTR outside a form (after connect):

```html
<span dir="ltr" data-orientation="horizontal" aria-disabled="false" data-slot="slider"
      class="<Root classes>" style="--radix-slider-thumb-transform: translateX(-50%);" data-controller="shadcn--slider">
  <span data-orientation="horizontal" data-slot="slider-track" class="<Track classes>">
    <span data-orientation="horizontal" data-slot="slider-range" class="<Range classes>" style="left: 25%; right: 25%;"></span>
  </span>
  <span style="transform: var(--radix-slider-thumb-transform); position: absolute; left: calc(25% + 4px);">
    <span role="slider" aria-label="Minimum" aria-valuemin="0" aria-valuenow="25" aria-valuemax="100"
          aria-orientation="horizontal" data-orientation="horizontal" tabindex="0"
          data-slot="slider-thumb" class="<Thumb classes>" data-radix-collection-item=""></span>
  </span>
  <span style="transform: var(--radix-slider-thumb-transform); position: absolute; left: calc(75% + -4px);">
    <span role="slider" aria-label="Maximum" aria-valuemin="0" aria-valuenow="75" aria-valuemax="100" ...></span>
  </span>
</span>
```

DOM order inside the Root: Track (containing Range), then for each thumb index: thumb wrapper span, then (only when it is a form control) its bubble `input` as the wrapper's next sibling (slider.mjs:539-555, Fragment).

Part `Slider` (Root, `data-slot="slider"`), slider.mjs:142-147, 238-248 (horizontal), 305-314 (vertical), 352-355 (`Primitive.span`):
- tag `span`. Attributes: `aria-disabled="true|false"` (ALWAYS present; React stringifies the boolean, slider.mjs:144), `data-disabled=""` only when disabled (slider.mjs:145), `data-orientation="horizontal|vertical"`, `dir="<use_direction(dir)>"` ONLY for horizontal (slider.mjs:241; vertical does not destructure `dir`, so a caller `dir:` passes through as a plain attribute and nothing is rendered when absent), `data-slot="slider"`, then caller attrs (they come after Radix's in `sliderProps` and win, e.g. `aria-disabled`, `id`, `aria-label`).
- `style`: caller `style` first, then `--radix-slider-thumb-transform: translateX(-50%)` (horizontal) / `translateY(50%)` (vertical) (slider.mjs:245-248, 311-314). Not caller-overridable.
- No `name`, `form`, `min`, `max`, `step`, `value`, `orientation`, `inverted` attributes (all destructured, slider.mjs:43-61, 204-214, 274-282).
- Classes verbatim from slider.tsx: `relative flex w-full touch-none items-center select-none data-[disabled]:opacity-50 data-[orientation=vertical]:h-full data-[orientation=vertical]:min-h-44 data-[orientation=vertical]:w-auto data-[orientation=vertical]:flex-col`, then `class:` through `cn`.

Track (`data-slot="slider-track"`), slider.mjs:394-407:
- tag `span`, `data-disabled=""` when disabled, `data-orientation`, `data-slot="slider-track"`. No style, no ARIA.
- Classes verbatim (no caller merge): `relative grow overflow-hidden rounded-full bg-muted data-[orientation=horizontal]:h-1.5 data-[orientation=horizontal]:w-full data-[orientation=vertical]:h-full data-[orientation=vertical]:w-1.5`.

Range (`data-slot="slider-range"`), slider.mjs:410-437:
- tag `span`, `data-orientation`, `data-disabled=""` when disabled, `data-slot="slider-range"`, no children.
- `style`: `<startEdge>: <offsetStart>%; <endEdge>: <offsetEnd>%` in that order, where `percentages = values.map(v => clamp(100 / (max - min) * (v - min), [0, 100]))` (slider.mjs:599-604, exact float op order: `percentPerStep = 100 / maxSteps`, then `percentPerStep * (value - min)`), `offsetStart = values.length > 1 ? Math.min(...percentages) : 0`, `offsetEnd = 100 - Math.max(...percentages)` (slider.mjs:421-422). Edges per orientation table below.
- Classes verbatim: `absolute bg-primary data-[orientation=horizontal]:h-full data-[orientation=vertical]:w-full`.

Orientation context (slider.mjs:195-200, 219-237, 286-304):

| case | startEdge | endEdge | direction | size |
|---|---|---|---|---|
| horizontal, (ltr and not inverted) or (rtl and inverted) | left | right | 1 | width |
| horizontal, (rtl and not inverted) or (ltr and inverted) | right | left | -1 | width |
| vertical, not inverted | bottom | top | 1 | height |
| vertical, inverted | top | bottom | -1 | height |

Thumb wrapper (no data-slot), slider.mjs:499-506:
- tag `span`, only a `style`: `transform: var(--radix-slider-thumb-transform); position: absolute; <startEdge>: calc(<percent>% + <offset>px)`, in that order. `percent` = the thumb's percentage (0 when its value is undefined, slider.mjs:461). `offset` = `getThumbInBoundsOffset(thumbSize, percent, direction)` when the measured thumb size along `size` is truthy, else `0` (slider.mjs:497-498, 623-628): `half = size / 2; o = (half / 50) * percent; (half - o * direction) * direction` (linearScale ratio first, slider.mjs:643-649).

Thumb (`data-slot="slider-thumb"`), slider.mjs:507-526:
- tag `span`, attributes: `role="slider"`, `aria-label` = Radix label (`getLabel`, slider.mjs:606-614: values.length > 2 -> `"Value <i+1> of <n>"`; == 2 -> `"Minimum"` / `"Maximum"`; else none; shadcn passes no aria-label to the Thumb, so a caller `aria-label` lands on the Root, never here), `aria-valuemin`, `aria-valuenow` (omitted when the value is undefined), `aria-valuemax`, `aria-orientation`, `data-orientation`, `data-disabled=""` when disabled, `tabindex="0"` only when NOT disabled (slider.mjs:519), `data-slot="slider-thumb"`, `data-radix-collection-item=""` (Collection.ItemSlot, collection.mjs:50).
- `style="display: none;"` only when its value is undefined (the shadcn two-thumbs-one-value quirk), otherwise no style attribute (slider.mjs:521).
- Classes verbatim (no caller merge, shadcn passes no className through): `block size-4 shrink-0 rounded-full border border-primary bg-white shadow-sm ring-ring/50 transition-[color,box-shadow] hover:ring-4 focus-visible:ring-4 focus-visible:outline-hidden disabled:pointer-events-none disabled:opacity-50`. `disabled:` never matches a `span`; the disabled look comes from the Root's `data-[disabled]:opacity-50`, and `hover:ring-4` still applies to a disabled thumb (scenario `disabled__hover-thumb`).

Bubble input (no data-slot), `SliderBubbleInput` slider.mjs:561-592:
- `<input style="display: none;" name="<name>" form="<form>" value="<value>">`: no `type`, no `aria-hidden`, no tabindex. `name` = `name` + `"[]"` when Radix holds more than one value (slider.mjs:460; the hidden second thumb of the quirk counts as one value, so no `[]`). `value` attribute from React `defaultValue` (omitted when the value is undefined); React keeps the attribute in sync on every update.
- Rendered iff form control: `!!form || !!thumb.closest("form")`, assumed `true` before the thumb is mounted (slider.mjs:458). Port: the server ALWAYS renders the inputs (same as Radix before mount; keeps no-JS form submission), the controller removes them in `connect()` when there is no `form:` and no `closest("form")`. Post-connect DOM equals the React DOM.

Number formatting: every number in an attribute or style (aria-value*, percentages, px offsets, input value) uses JS `String(Number)` semantics (integers without `.0`, shortest round-trip decimals). The Ruby side must format accordingly (`50`, `12.5`, `33.333333333333336`, negative offsets as `+ -4px`).

Server vs Stimulus: the server renders every attribute above for the initial values, with thumb wrapper offsets of `0px` (size unknown on the server, identical to React's first render where `useSize` is still undefined). Stimulus (`shadcn--slider`, host = the Root span) measures the thumbs on connect and writes the in-bounds offsets, removes non-form bubble inputs, and on every change updates `aria-valuenow`, the Range and wrapper styles, and the bubble inputs. Thumb elements never move in the DOM; values are re-sorted across them. Styles are written through `element.style` (like React) so the serialized `style` attribute matches the oracle's CSSOM serialization. No ids are generated.

## Behavior

States: per-thumb numeric values (array, always sorted ascending, slider.mjs:593-597); orthogonal `disabled`, `orientation`, `dir`, `inverted`. No `data-state`.

Value update (`updateValues(value, atIndex, { commit })`, slider.mjs:106-126), used by every input:
1. Snap: `roundValue(Math.round((value - min) / step) * step + min, decimalCount(step))` (decimals from `step.toString()`, exponent-aware, slider.mjs:650-667), then `clamp` to `[min, max]`.
2. If `preserve_thumb_order`: clamp further to `[prev[atIndex-1] + minStepsBetweenThumbs*step (or min), prev[atIndex+1] - minStepsBetweenThumbs*step (or max)]`.
3. `next = sort(prev with [atIndex] = constrained)`. If `min_steps_between_thumbs > 0` and the smallest gap between neighbours is below `min_steps_between_thumbs * step`, reject (no change, no event).
4. The active index becomes `preserve_thumb_order ? atIndex : next.indexOf(constrained)` (so thumbs "swap": crossing another thumb moves the active index and focus to the other thumb).
5. If `String(next) === String(prev)`: no change, no event, no focus. Otherwise apply; `commit` (keyboard) dispatches `value-commit`.
6. On change (Radix `onChange`, slider.mjs:72-80): focus `thumbs[activeIndex]` with `{ preventScroll: true, focusVisible: <keyboard interaction> }`, reset the keyboard flag, dispatch `value-change`.
7. Bubble inputs whose value changed: set the `value` property with the native `HTMLInputElement.prototype` setter and dispatch `new Event("input", { bubbles: true })` (slider.mjs:568-579); the `value` attribute follows.

Keyboard (keydown on the Root, bubbling from a focused thumb; slider.mjs:356-367; every handled key gets `preventDefault()`; nothing when disabled):

| Key | Effect |
|---|---|
| `Home` | `updateValues(min, 0, commit)`: ALWAYS the first thumb, whichever thumb is focused (slider.mjs:160-165); focus moves to the thumb that ends at `min` (focusVisible) |
| `End` | `updateValues(max, values.length - 1, commit)`: always the last thumb (slider.mjs:166-171) |
| Arrow keys, `PageUp`, `PageDown` | step the ACTIVE thumb (the last focused one, set on thumb `focus`, slider.mjs:522-524): `getNextStepValue(values[active], { min, step, direction, multiplier })` then `updateValues(..., active, commit)` (slider.mjs:172-188, 669-688) |
| `Shift` + Arrow, `PageUp`, `PageDown` | multiplier 10 (slider.mjs:175-177) |

Step direction: back keys per slide direction (slider.mjs:28-33, 261-265, 327-331); every other step key is forward (+1):

| slide direction | back keys (-1) |
|---|---|
| from-left (horizontal, ltr xor inverted = left start) | Home, PageDown, ArrowDown, ArrowLeft |
| from-right (horizontal, rtl xor inverted) | Home, PageDown, ArrowDown, ArrowRight |
| from-bottom (vertical) | Home, PageDown, ArrowDown, ArrowLeft |
| from-top (vertical inverted) | Home, PageDown, ArrowUp, ArrowLeft |

`getNextStepValue`: if the value is aligned to the step grid (after rounding to the step's decimals) -> `nearestSteps + multiplier * direction`; otherwise forward -> `ceil(stepsFromMin)`, back -> `floor(stepsFromMin)` (multiplier ignored for unaligned values); result `roundValue(nextSteps * step + min)`, then `updateValues` snaps and clamps.

Tab: each visible, non-disabled thumb is a tab stop (`tabindex="0"`) in DOM order; the hidden quirk thumb (`display: none`) and disabled thumbs (no tabindex) are skipped. No roving focus. Focus ring only on `:focus-visible`.

Pointer (slider.mjs:368-388; Root listeners, `pointerdown` NOT `click`):
- `pointerdown` (any target inside the Root): first the Slider handler (when not disabled) snapshots the values for commit and clears the keyboard flag (slider.mjs:148-153); then `event.target.setPointerCapture(pointerId)` and `preventDefault()` (no native focus, no text selection). If the target is a thumb: `thumb.focus({ preventScroll: true, focusVisible: false })` and NO value change. Otherwise slide start: value from the pointer, `updateValues(value, closestIndex)` where `closestIndex` = index of the smallest `|value - v|`, first one on ties (slider.mjs:616-621).
- `pointermove`: if `event.target.hasPointerCapture(pointerId)`: slide move with `updateValues(value, activeIndex)` (no commit).
- `pointerup`: if captured: release capture, clear the cached rect, dispatch `value-commit` when `String(values) !== String(valuesAtPointerdown)`.
- Value from pointer (slider.mjs:221-228, 288-295): rect = the ROOT's `getBoundingClientRect()` cached from slide start until slide end; horizontal `linearScale([0, rect.width], fromLeft ? [min, max] : [max, min])(clientX - rect.left)`; vertical `linearScale([0, rect.height], fromBottom ? [max, min] : [min, max])(clientY - rect.top)`. Values outside the rect clamp in `updateValues`.
- Disabled: capture and `preventDefault` still happen, but slide start/move/end are no-ops (slider.mjs:157-159) and thumbs are not focusable.
- Focus after a pointer change uses `focusVisible: false`, so no `:focus-visible` ring after mouse use.

Form integration:
- Reset: on the associated form's `reset` event (`form:` -> `document.getElementById(form)`, else `root.closest("form")`) set the values back to those captured at first render (slider.mjs:83-91). This goes through the same change path (focus of the active thumb with `focusVisible` = keyboard flag, `value-change`, bubble inputs). Listener removed on disconnect.
- Thumb size: on connect read `offsetWidth/offsetHeight` of each thumb, then follow a `ResizeObserver` (`box: "border-box"`, `borderBoxSize[0].inlineSize/blockSize`, rAF-debounced), exactly like `useSize` (size.mjs:7-47), and rewrite the wrapper offsets. Cancel rAF and unobserve on disconnect.

Timers: none. Presence: none (only the thumb's CSS `transition-[color,box-shadow]`). No dismissal, no scroll lock, no positioning library (CSS absolute + percentages). Direction: `dir` only for horizontal, from `use_direction(dir)` on the server (DirectionProvider aware, never `html[dir]`, dir.mjs:17-20); the controller reads the Root's own `dir` attribute.

Primitives composed: `pointer_capture` (setPointerCapture/hasPointerCapture/release on the event target), `form_bubble_input` (create/remove decision, native value setter + bubbling `input` event, form reset hook; slider variant: `display: none`, `input` event instead of `click`), `direction` (reads the host's own `dir`, default `ltr`). Not used: roving focus, focus scope, dismissable layer, presence, positioner.

Turbo: `disconnect()` removes the reset listener and ResizeObservers and releases any pointer capture; `connect()` reconciles from the DOM (radix-stimulus R4).

## Dependencies

None. Slider renders no other `Components::V2` component and no icon (manifest `icons: []`, `registry_dependencies: []`). Server-side it includes `Components::V2::Direction::Consumer` for `use_direction` (Direction spec). The `field-slider` registry example uses `Field`/`FieldTitle`/`FieldDescription`, which are not dependencies of `slider`; its scenario keeps the example's outer `_div` wrapper and the Slider with the example's exact props, and omits the Field parts (no V2 Field exists yet and `_` nodes must not stand in for shadcn parts).

## Deviations

One, API only (no DOM or class difference):

- `as_child:` is not supported on `Components::V2::Slider`. Reason: Radix Root is a `Primitive.span` that accepts `asChild`, but shadcn's `Slider` always passes the Track plus one or more Thumbs as children, and Radix `Slot` throws when it does not receive exactly one element child (slot.mjs `React.Children.count(children) === 1` else `createSlotError`), so `asChild` cannot render in React either; no registry example uses it. Entry written to `gems/chadcn/dev/port/deviations/slider.json`:

```json
{ "reason": "shadcn Slider always passes Track plus Thumb children to SliderPrimitive.Root, and Radix Slot throws unless it receives exactly one element child, so asChild cannot render in React; as_child is therefore not offered", "allow_tokens": [], "allow_missing_tokens": [], "api": ["Slider: as_child not supported"] }
```
