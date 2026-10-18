# RadioGroup

Oracle: `gems/phlex-shadcn/dev/port/oracle/src/radio-group.tsx` (manifest `source_sha` cfc4f99ee68be2fb, tier `radix_stateful`), wrapping `RadioGroupPrimitive.Root` / `.Item` / `.Indicator` from `radix-ui` 1.7.0 -> `@radix-ui/react-radio-group` 1.4.8 (`gems/phlex-shadcn/dev/react-shadcn-catalog/node_modules/@radix-ui/react-radio-group/dist/index.mjs`, cited as `rg:<line>`; it bundles `src/radio.tsx` at rg:16-216 and `src/radio-group.tsx` at rg:218-420), built on `@radix-ui/react-roving-focus` 1.1.20 (`rf:<line>`), `@radix-ui/react-collection` 1.1.16 (`col:<line>`), `@radix-ui/react-direction` 1.1.5 (`dir:<line>`), `@radix-ui/react-presence`, `@radix-ui/react-use-size`. Icon `CircleIcon` from `lucide-react` 0.577.0 (`icons/circle.js`: one `<circle cx="12" cy="12" r="10">`). React 19. Registry examples read live (network): `radio-group-demo`, `field-radio`, `field-choice-card`, `form-rhf-radiogroup` (`form-tanstack-radiogroup` / `form-formisch-radiogroup` are the same markup as rhf with another form library and are not separate scenarios).

## API

Two exports, two Ruby classes. `RadioGroupPrimitive.Indicator` is not exported by shadcn; `RadioGroup::Item` renders it internally.

### `RadioGroup` -> `Components::V2::RadioGroup`

```ruby
Components::V2::RadioGroup.new(
  value: nil,            # controlled value (String; symbols -> to_s). nil = uncontrolled (useControllableState: controlled iff prop !== undefined, rg:247-252)
  default_value: nil,    # uncontrolled initial value; nil -> no item checked (rg:249 `defaultValue ?? null`)
  disabled: false,       # rg:238; disables every item (rg:313 `context.disabled || disabled`)
  required: false,       # rg:237; aria-required on the root (always rendered, "false" by default), `required` on bubble inputs
  name: nil,             # bubble inputs only (rg:321, rg:182)
  form: nil,             # bubble inputs `form` attr (rg:184), form-control detection (rg:49) and reset target (rg:257)
  orientation: nil,      # nil | "horizontal" | "vertical" (symbols accepted); rg:239, aria-orientation + data-orientation, arrow-key filtering (rf:227-236)
  dir: nil,              # nil | "ltr" | "rtl"; use_direction(dir) = dir || nearest Direction::Provider || "ltr" (dir:17-20, rg:246). NEVER html[dir]
  loop: true,            # rg:241 (Radix RovingFocusGroup default is false, rf:46, but RadioGroup passes loop=true)
  as_child: false,       # false | tag symbol | V2 component instance (Radix Slot on Primitive.div, rg:283; see api-mapping "as_child")
  class: nil,            # merged last into "grid gap-3" through cn (tailwind_merge), caller wins
  **attrs                # id, aria: {}, data: {}, "aria-label", "aria-invalid", title, style... pass through to the root div (after Radix attrs, rg:290)
) { items and any other markup }
```

- `value:` / `default_value:` compare with `==` to each item's `value:` after `to_s` (rg:318 `context.value === value`). `value: ""` is a valid controlled value that matches no item (form-rhf-radiogroup).
- `orientation:` / `dir:` accept strings and symbols; any other value raises `ArgumentError`.
- Controlled (`value:` given): a click/Space/arrow-select does NOT change `aria-checked`/`data-state`/Indicator/bubble inputs; it only dispatches `value-change` with the item value (useControllableState calls `onChange` only when `next !== prop`). Roving focus state (which item has `tabindex=0`) is NOT controlled and still moves (rf:58-63, no `currentTabStopId` passed by RadioGroup).
- Uncontrolled: the controller owns the value after connect.
- Event: `shadcn--radio-group:value-change`, `detail: { value: "<item value>" }`, dispatched from the root element after the DOM update (uncontrolled) or instead of it (controlled). Also dispatched on form reset when the restored value differs (rg:259). Not cancelable (`onValueChange` is not preventable). Consumer `onClick`/`onKeyDown`/`onFocus` on items are plain `data: { action: }`; Radix composes consumer first and skips its own handler when the consumer called `preventDefault()` (`composeEventHandlers`, rg:100, rg:366-373, rf:179-204), so the controller checks `event.defaultPrevented`.
- `ref` has no equivalent.

### `RadioGroupItem` -> `Components::V2::RadioGroup::Item`

```ruby
Components::V2::RadioGroup::Item.new(
  value:,                # required String (symbols -> to_s); on the button `value` attribute and the bubble input (rg:97, rg:183)
  disabled: false,       # rg:381; effective disabled = group.disabled || disabled (rg:313)
  class: nil,            # merged last into the Item classes through cn, caller wins
  **attrs                # id, aria-label, aria-invalid, aria-describedby, data: {}, ... pass through to the button (spread after Radix attrs, rg:98)
)
```

- No block: shadcn spreads `{...props}` and then sets the Indicator as JSX children, which overrides any `children` prop (radio-group.tsx), so caller children never render. Ruby: a block passed to `Item` is ignored (never yielded), matching React.
- Must be rendered inside a `Components::V2::RadioGroup` (Radix context error otherwise, `useRadioGroupContext`, rg:311). Ruby raises `ArgumentError` when no enclosing group is found in the render context.
- `as_child:` is NOT offered (see Deviations).

## Structure

Final DOM (after React mount / after Stimulus connect), uncontrolled, `default_value: "b"`, not inside a form:

```html
<div role="radiogroup" aria-required="false" dir="ltr" data-slot="radio-group" class="grid gap-3"
     tabindex="0" style="outline: none;" data-controller="shadcn--radio-group" ...>
  <button type="button" role="radio" aria-checked="false" data-state="unchecked" value="a"
          data-slot="radio-group-item" class="<Item classes>" tabindex="-1" data-radix-collection-item=""></button>
  <button type="button" role="radio" aria-checked="true" data-state="checked" value="b"
          data-slot="radio-group-item" class="<Item classes>" tabindex="-1" data-radix-collection-item="">
    <span data-state="checked" data-slot="radio-group-indicator" class="relative flex items-center justify-center">
      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor"
           stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
           class="lucide lucide-circle absolute top-1/2 left-1/2 size-2 -translate-x-1/2 -translate-y-1/2 fill-primary" aria-hidden="true">
        <circle cx="12" cy="12" r="10"></circle>
      </svg>
    </span>
  </button>
  ...
</div>
```

### Part `RadioGroup` (`data-slot="radio-group"`)

Radix: `RovingFocusGroup.Root asChild` (rf:42-131) slotted onto `Primitive.div` (rg:274-294); Slot merge, child props win.
- tag `div` (or the `as_child` element).
- `role="radiogroup"` (rg:285).
- `aria-required="true" | "false"`: ALWAYS present (React stringifies the boolean `required`, rg:286; default `false`).
- `aria-orientation` only when `orientation:` is given (rg:287); `data-orientation` with the same value only when given (rf:101).
- `data-disabled=""` only when the group is disabled (rg:288).
- `dir="ltr" | "rtl"`: ALWAYS present, value of `use_direction(dir)` (rg:289).
- `data-slot="radio-group"`, `class` = `cn("grid gap-3", class)` (radio-group.tsx).
- `tabindex`: `"0"` when at least one item is focusable (not disabled), `"-1"` when none is (`focusableItemsCount === 0`, rf:100) or transiently while Shift+Tab leaves the group (`isTabbingBackOut`, rf:64, 88, 100, 126). Server renders the post-mount value (`0` iff any item is enabled) so the first paint equals React after mount.
- `style="outline: none;"` (rf:104), merged with a caller `style` (caller keys win).
- Caller `**attrs` (`id`, `aria-label`, `aria-invalid`, `data-*`, `title`) pass through.
- Order of children: exactly the block.

### Part `RadioGroupItem` (`data-slot="radio-group-item"`)

Radix: `Collection.ItemSlot` (col:50, adds `data-radix-collection-item=""`) > `RovingFocusGroup.Item asChild` (rf:133-211, `Primitive.span` slotted) > `RadioTrigger` `Primitive.button` (rg:74-113), then (when a form control) the bubble input as next sibling (rg:388-403, Fragment).
- tag `button`, `type="button"`, `role="radio"` (rg:91-92).
- `aria-checked="true" | "false"`: always present (rg:93).
- `data-state="checked" | "unchecked"` (`getState`, rg:213-215).
- `data-disabled=""` and `disabled=""` only when effectively disabled (rg:95-96).
- `value="<value>"` (rg:97).
- `tabindex="0" | "-1"`: `0` only for the current tab stop (`currentTabStopId === id`, rf:145, 175). Initially NO item is the tab stop (RadioGroup passes no `defaultCurrentTabStopId`, rf:58-63), so every item renders `tabindex="-1"` and the group (`tabindex="0"`) is the Tab entry point. The stop becomes the item that last received focus or mousedown (rf:179-183) and stays after focus leaves.
- `data-orientation` only when the group has `orientation:` (rf:176).
- `data-radix-collection-item=""` (col:50): always.
- `data-slot="radio-group-item"`; `class` = `cn("aspect-square size-4 shrink-0 rounded-full border border-input text-primary shadow-xs transition-[color,box-shadow] outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:bg-input/30 dark:aria-invalid:ring-destructive/40", class)` (verbatim, radio-group.tsx).
- Caller attrs (`id`, `aria-label`, `aria-invalid`, `aria-describedby`, `data-*`) win over Radix's (spread after, rg:98).
- No `aria-required`, no `name` on the button.
- Child: the Indicator, only while checked.

### Indicator (`data-slot="radio-group-indicator"`, internal)

Radix `RadioIndicator` (rg:115-129) inside `Presence present={forceMount || checked}` (rg:119; shadcn passes no `forceMount`).
- tag `span`, `data-state` mirrors the item (rg:122), `data-disabled=""` when effectively disabled (rg:123), `data-slot="radio-group-indicator"`, `class="relative flex items-center justify-center"` (verbatim, no caller merge). No inline style (unlike Checkbox).
- Rendered only when the item is checked; unchecked items are empty buttons.
- Child: `Components::V2::Icon.new(name: "circle", class: "absolute top-1/2 left-1/2 size-2 -translate-x-1/2 -translate-y-1/2 fill-primary")` -> lucide 0.577.0 markup `class="lucide lucide-circle <classes>"`, `aria-hidden="true"`, `<circle cx="12" cy="12" r="10">`.

### Bubble input (no data-slot, internal)

Radix `RadioBubbleInput` (rg:131-208), next sibling of the item button:
- `<input type="radio" aria-hidden="true" tabindex="-1">`; `checked=""` attribute iff the item is checked on first render (`defaultChecked: defaultCheckedRef.current`, rg:173, 179); `required=""` iff group `required` (React omits `required={false}`); `disabled=""` iff effectively disabled; `name`, `value`, `form` when given (rg:180-184).
- Style, Radix order: `width`/`height` in px once measured (`...controlSize`, rg:195, from `useSize(control)` = button border-box size), then `position: absolute; pointer-events: none; opacity: 0; margin: 0px; transform: translateX(-100%)` (rg:196-203).
- Rendered iff a form control: `!!form || !!control.closest("form")`, assumed `true` before mount (rg:49-52, "so that events bubble to forms without JS (SSR)"). Port: the server ALWAYS renders it (identical to Radix SSR); each item's controller logic removes it in `connect()` when the group has no `form:` and the button has no `closest("form")`. Post-connect DOM equals React in both cases.

Server vs Stimulus: the server renders every attribute above for the initial state (including `tabindex` values, `dir`, the Indicator for the checked item and the bubble inputs). Stimulus (`shadcn--radio-group`, host = the root element; there is ONE controller for the group, items are targets, no per-item controller) updates `aria-checked`, `data-state` on items and Indicators, mounts/unmounts Indicators, roving `tabindex`, group `tabindex`, bubble inputs. No ids are generated: Radix's roving `useId` tab-stop ids (rf:144) are internal and never reach the DOM; the port tracks the tab stop by element reference. Only caller `id:` attributes appear (for `<label for>`).

## Behavior

States: per item `checked` / `unchecked`; orthogonal `disabled` (item or group). Group value: one string or none. `aria-invalid` is a caller attribute (style only).

### Selection (rg:100-109, rg:324)

1. Native `click` on an item button (unless `event.defaultPrevented` by a consumer handler): if the item is NOT checked, count a user interaction and set the group value to the item's value (`onCheck` -> `context.onValueChange(value)`). Clicking an already-checked item does nothing (no event).
2. If the item has a bubble input and is a form control: record whether the consumer already stopped propagation; if not, `event.stopPropagation()` on the button click (rg:105-108).
3. On every value change, for every item whose checked flag changed (the newly checked AND the previously checked one), sync its bubble input (rg:151-172): set `checked` through `HTMLInputElement.prototype` setter, dispatch `new Event("click", { bubbles })` with `bubbles = !(isUserInteraction && consumerStoppedPropagation)`; for non-user changes (reset, controlled re-render) the input's own click listener stops propagation (`shouldStopClickPropagationRef`, rg:166, 188-192).
4. Update DOM (`aria-checked`, `data-state` on button and Indicator, Indicator presence) and dispatch `shadcn--radio-group:value-change`.
- Controlled: step 1 dispatches only; the DOM stays server-rendered.
- There is no way to uncheck via user input (no toggle-off).

### Keyboard

The arrow handling is RovingFocusGroup (rf:184-204) plus RadioGroup's "focus while arrow pressed = click" rule (rg:338-352, 369-373).

| Key (focus on an item) | Result |
|---|---|
| ArrowDown / ArrowRight | focus the next focusable (enabled) item, wrapping (`loop: true`); the focus then CHECKS it (see below) |
| ArrowUp / ArrowLeft | focus the previous focusable item, wrapping; checks it |
| with `dir: "rtl"` | ArrowLeft and ArrowRight swap meaning (`getDirectionAwareKey`, rf:222-226); Up/Down unchanged |
| with `orientation: "vertical"` | ArrowLeft/ArrowRight ignored (no preventDefault) (rf:229-231) |
| with `orientation: "horizontal"` | ArrowUp/ArrowDown ignored (rf:232-234) |
| Home / PageUp | focus the first focusable item, does NOT check it (not in `ARROW_KEYS`, rg:220) |
| End / PageDown | focus the last focusable item, does NOT check it |
| any of the above with Meta/Ctrl/Alt/Shift | ignored, no preventDefault (rf:192) |
| `loop: false` | at the ends, Next/Prev does nothing (`slice`, rf:200) |
| Space | native button activation -> click -> checks (if unchecked) |
| Enter | `keydown` `preventDefault()` -> no click, no check (rg:366-368) |
| Tab | leaves the group (items other than the tab stop are `tabindex=-1`) |
| Shift+Tab | sets `isTabbingBackOut` -> group `tabindex="-1"` before default navigation, so focus skips the group div and leaves; any `focusout` inside the group resets it -> `tabindex="0"` (rf:185-188, 88, 126) |

Mechanics to reproduce exactly:
- Key handling only when `event.target === event.currentTarget` (the item itself, rf:189); Shift+Tab is checked before that.
- When a focus intent exists: `preventDefault()`, candidates = enabled items in DOM order (Collection order = `querySelectorAll("[data-radix-collection-item]")` inside the group, col:59), reversed for prev/last, rotated after the current index for prev/next (`wrapArray`, rf:247-249), then `setTimeout(() => focusFirst(candidates))` (rf:202, a macrotask, not synchronous). `focusFirst` (rf:238-245) focuses candidates in order until `document.activeElement` changes, stopping if it reaches the previously focused element.
- "Arrow-select": each item installs `document` `keydown` (sets `isArrowKeyPressed = true` when `event.key` is one of `ArrowUp/ArrowDown/ArrowLeft/ArrowRight`, regardless of modifiers or target) and `keyup` (resets to `false` on ANY keyup) listeners (rg:339-352). On item `focus`, if `isArrowKeyPressed`, call `button.click()` (rg:369-373), which runs the Selection rules (so a controlled group only dispatches). Port: one pair of document listeners owned by the group controller (observable behavior identical), removed on disconnect.
- Item `mousedown`: if not focusable, `preventDefault()`; else the item becomes the tab stop (rf:179-182). Item `focus` (any cause) makes it the tab stop (rf:183).

### Focus entry (rf:105-125)

- Group `mousedown` (bubbling from anywhere inside, including items and labels) sets `isClickFocus = true`.
- Group `focus` (focusin, React `onFocus` bubbles): when `event.target === group` AND not click focus AND not tabbing back out: dispatch a cancelable, non-bubbling `CustomEvent("rovingFocusGroup.onEntryFocus")` on the group (RadioGroup adds no listener, so it is never prevented); then focus the first of [checked item, current tab-stop item, ...enabled items in order] that is focusable (disabled items are filtered out first, so a disabled checked item is skipped). `preventScroll: false`. Then `isClickFocus = false` (always, also for item focus).
- Consequences covered by scenarios: Tab from before the group lands on the checked item, else on the previously focused item, else on the first enabled item; Shift+Tab from after the group, when no item is the tab stop yet, lands on the group div and is redirected the same way; a mouse click on non-focusable space inside the group (e.g. the row `div` right of a label) focuses the group div itself with no redirect (outline none), and arrow keys there do nothing (target is not an item).
- Programmatic `item.focus()` (no arrow key down) only moves focus and the tab stop; it does not check.
- Focus ring only on `:focus-visible` (keyboard); mouse clicks focus without a visible ring.
- A fully disabled group has `tabindex="-1"` and disabled items: Tab skips it entirely.

### Pointer

Plain `click` (not `pointerdown`). Disabled buttons get no click; a `<label for>` pointing to a disabled item does nothing. `<label for="<id>">` click and a wrapping `<label>` click activate the button and check it (radio-group-demo, field-radio, field-choice-card).

### Presence (Indicator)

Mount is immediate when the item becomes checked. On uncheck Presence keeps the node only if the computed `animation-name` is not `none` and changed, waiting for `animationend`; shadcn's Indicator has no animation class, so it is removed synchronously. Port: use the `presence` primitive so a caller animation would behave like Radix; in the oracle configuration it degenerates to an immediate remove. While exiting the Indicator would carry `data-state="unchecked"`.

### Form integration

- Reset (rg:255-263): the associated form is `document.getElementById(form)` when `form:` is given, else `root.closest("form")` (note: NOT `button.form` as in Checkbox); only if it is an `HTMLFormElement`. On its `reset` event set the value back to the value captured at first render (`initialValueRef`, rg:255), which may be `nil` (no item checked). Controlled: dispatches `value-change` only if different. Listener removed on disconnect.
- Bubble input size: on connect `{ width: offsetWidth, height: offsetHeight }` of each item button, then a `ResizeObserver` (`box: "border-box"`, rAF-debounced), exactly like `use-size`. Cancel rAF and unobserve on disconnect.
- Bubble inputs with the same `name` form a native radio group; the per-input setter calls of step 3 keep them in sync either way.

### Not applicable

Timers: none (only the `setTimeout(0)` focus hop). No dismissal, no scroll lock, no positioning, no portal, no typeahead (RovingFocusGroup has none).

### Primitives composed

`roving_focus` (orientation/dir/loop key mapping, `setTimeout` focusFirst, tab-stop `tabindex`, group `tabindex` with focusable-count and Shift+Tab back-out, entry focus with click-focus guard), `collection` (DOM-ordered items; must use the `data-radix-collection-item` attribute the oracle renders, not a new attribute), `direction` (reads the root's own `dir` attribute), `form_bubble_input` (radio variant: create/remove decision, native setter + synthetic click with Radix's bubbles/stop rules, size observation, reset hook with `form`-id lookup), `presence` (Indicator). Arrow-select (document keydown/keyup flag + click on focus) is RadioGroup-specific logic in the controller.

Turbo: `disconnect()` removes document key listeners, reset listener, ResizeObservers, rAF and pending focus timeouts; `connect()` reconciles from the DOM (radix-stimulus R4).

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Phlex::Shadcn::RadioGroup` MUST `yield self` from `view_template`; `Phlex::Shadcn::Base` generates one helper per nested part (`const_added`), each exactly `render RadioGroup::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Phlex::Shadcn::RadioGroup::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `radio_group.item` | `RadioGroup::Item` | `RadioGroupItem` |


Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Components::V2::Icon` (`circle`) inside the Indicator (manifest `icons: ["CircleIcon"]`).
- `Components::V2::Direction` (`Consumer` mixin / `use_direction`) for the `dir` attribute (spec `direction.md`).
- No other V2 component (`registry_dependencies: []`). Registry examples use `Label` (radio-group-demo) and `Field*` (field-radio, field-choice-card, form-rhf-radiogroup), which are not dependencies of `radio-group`; their scenarios use raw `_label` / `_div` / `_p` / `_fieldset` / `_form` with the corresponding classes instead.

## Deviations

One, API only (no DOM or class difference):

- `as_child:` is not supported on `Components::V2::RadioGroup::Item`. Reason: Radix `RadioTrigger` (`Primitive.button`) accepts `asChild`, but shadcn's `RadioGroupItem` always renders `RadioGroupPrimitive.Indicator` as its only child, so Radix `Slot` would merge the radio's attributes and handlers onto the Indicator, which is absent while unchecked (Presence) and a `span` otherwise: no usable control. No registry example uses it. `as_child:` on the `RadioGroup` root IS supported (scenario `as-child-root`). Entry in `gems/phlex-shadcn/dev/port/deviations/radio-group.json`:

```json
{ "reason": "shadcn RadioGroupItem always passes RadioGroupPrimitive.Indicator as the Item's only child, so Radix asChild would merge the radio onto the indicator (absent while unchecked); as_child is therefore not offered on RadioGroup::Item (it is supported on the RadioGroup root)", "allow_tokens": [], "allow_missing_tokens": [], "api": ["RadioGroup::Item: as_child not supported"] }
```
