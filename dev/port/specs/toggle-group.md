# ToggleGroup

Oracle: `dev/port/oracle/src/toggle-group.tsx` (manifest `source_sha` 45186473eaa30a96, tier `radix_stateful`), wrapping `ToggleGroupPrimitive.Root` / `.Item` from `radix-ui` 1.7.0 -> `@radix-ui/react-toggle-group` 1.1.20 (`dev/react-shadcn-catalog/node_modules/@radix-ui/react-toggle-group/dist/index.mjs`, cited `tg:<line>`), built on `@radix-ui/react-toggle` 1.1.19 (`toggle:<line>`), `@radix-ui/react-roving-focus` 1.1.20 (`rf:<line>`), `@radix-ui/react-collection` 1.1.16 (`col:<line>`), `@radix-ui/react-direction` 1.1.5 (`dir:<line>`), `@radix-ui/react-use-controllable-state` 1.2.6 (`ucs:<line>`), `@radix-ui/primitive` (`primitive:<line>`). Item classes come from `toggleVariants` in `dev/port/oracle/src/toggle.tsx` (spec `toggle.md`). React 19. Registry examples read live (network): `toggle-group-demo`, `toggle-group-outline`, `toggle-group-single`, `toggle-group-sm`, `toggle-group-lg`, `toggle-group-disabled`, `toggle-group-spacing`. Same roving-focus contract as `radio-group.md` and `tabs.md`, without RadioGroup's arrow-select and without Tabs' activation-on-focus.

## API

Two exports, two Ruby classes (name rule: strip the `ToggleGroup` prefix).

### `ToggleGroup` -> `Chadcn::ToggleGroup`

```ruby
Chadcn::ToggleGroup.new(
  type:,                 # REQUIRED "single" | "multiple" (strings or symbols). Radix throws without it (tg:34); Ruby raises ArgumentError
  value: nil,            # controlled. single: String ("" = none); multiple: Array of Strings. nil = uncontrolled (ucs:20)
  default_value: nil,    # uncontrolled initial. single: nil -> "" (tg:47 `defaultValue ?? ""`); multiple: nil -> [] (tg:73)
  variant: nil,          # nil | "default" | "outline" (symbols accepted). Not defaulted by shadcn (destructured without default)
  size: nil,             # nil | "default" | "sm" | "lg" (symbols accepted, :default ok)
  spacing: 0,            # Numeric, shadcn default `spacing = 0`; TS type number. Anything else raises ArgumentError
  disabled: false,       # tg:103; disables every item (tg:134 `context.disabled || props.disabled`); NOT rendered on the root
  roving_focus: true,    # tg:104 `rovingFocus = true`; false renders no RovingFocusGroup (tg:113-123)
  orientation: nil,      # nil | "horizontal" | "vertical" (symbols accepted); only feeds RovingFocusGroup (tg:118)
  dir: nil,              # nil | "ltr" | "rtl"; use_direction(dir) = dir || nearest Direction::Provider || "ltr" (dir:17-20, tg:111). NEVER html[dir]
  loop: true,            # tg:107 (RovingFocusGroup's own default is false, rf:46; ToggleGroup passes true)
  as_child: false,       # false | tag symbol | Chadcn component instance (Primitive.div asChild, tg:121; Slot merge per api-mapping)
  class: nil,            # merged last into the root classes through cn (tailwind_merge), caller wins
  **attrs                # id, role, aria: {}, data: {}, "aria-label", title, style... onto the root div (spread after shadcn's attrs)
) { items and any other markup }
```

- `type:` accepts `"single"`, `:single`, `"multiple"`, `:multiple`; any other value raises `ArgumentError` (same message intent as tg:34).
- `value:` / `default_value:` items compare with `==` after `to_s` (`valueContext.value.includes(props.value)`, tg:133). Single uncontrolled internal value is a String, `""` meaning none (`value ? [value] : []`, tg:56). A single `value: ""` is a valid controlled value that presses nothing. Passing an Array to a single group or a String to a multiple group raises `ArgumentError`.
- `variant:`/`size:` are passed to items via context (tg.tsx `ToggleGroupContext.Provider value={{ variant, size, spacing }}`); the root itself only reflects them in `data-variant`/`data-size`.
- `spacing:` is rendered with JavaScript number formatting (React stringifies the number): `0` -> `"0"`, `2` -> `"2"`, `0.5` -> `"0.5"`, `2.0` -> `"2"` (Ruby must not emit `"2.0"`).
- Controlled (`value:` given): a click/Space/Enter on an item does NOT change any item's `data-state`/`aria-*`; it only dispatches `value-change` with the would-be value (ucs:38-42: `onChange` only when `next !== prop`; for `multiple` the next array is always a new reference, so it always fires; for `single` it fires unless the next string equals `value`, which cannot happen on a click because a click either activates a different item or deactivates to `""`). Roving tab-stop state is NOT controlled and still moves (rf:58-63).
- Uncontrolled: the controller owns the value after connect.
- Event: `chadcn--toggle-group:value-change`, dispatched from the root element, `detail: { value }`:
  - single: the newly pressed item's value, or `""` when the pressed item is clicked again (tg:57-58, toggle:30-34 -> tg:163-169 `onItemDeactivate` -> `setValue("")`).
  - multiple: the new Array; activation APPENDS (`[...prevValue, itemValue]`, tg:78) so order is activation order, not DOM order; deactivation filters (tg:82).
  - Uncontrolled: dispatched after the DOM update (useUncontrolledState effect, ucs:62-67); controlled: instead of updating. Not cancelable (`onValueChange` is not preventable).
- Consumer handlers (`onClick`, `onKeyDown`, `onMouseDown`, `onFocus`) are plain `data: { action: }` on items/root. Radix runs the consumer first and skips its own logic when the consumer called `preventDefault()` (primitive:6-12 `composeEventHandlers`; toggle:30, rf:105-126, rf:179-204), so the controller checks `event.defaultPrevented` and its action descriptors come after the caller's.
- `ref` has no equivalent.

### `ToggleGroupItem` -> `Chadcn::ToggleGroup::Item`

```ruby
Chadcn::ToggleGroup::Item.new(
  value:,                # REQUIRED String (symbols -> to_s). Consumed by Radix (tg:153): NOT rendered as an attribute
  variant: nil,          # used only when the group has no variant: `context.variant || variant` (tg.tsx)
  size: nil,             # used only when the group has no size: `context.size || size`
  disabled: false,       # effective disabled = group.disabled || disabled (tg:134)
  as_child: false,       # false | tag symbol | Chadcn component instance (Toggle is Primitive.button with asChild, toggle:22)
  class: nil,            # merged last through cn, caller wins
  **attrs                # id, aria-label, aria-invalid, title, data: {}, type... onto the button (spread after Radix attrs)
) { children }
```

- Precedence is group-first: with `ToggleGroup.new(variant: "outline")` an item's `variant: "default"` is ignored (scenario `item-variant__group-wins`); the item value applies only when the group's is `nil` (`item-variant__no-group-variant`). Same for `size`. An explicit group `"default"` also wins (`item-variant__explicit-default-group`).
- Must be rendered inside a `Chadcn::ToggleGroup` (Radix context error otherwise, `useToggleGroupValueContext`, tg:130). Ruby raises `ArgumentError` when no enclosing group is found in the render context.
- `as_child:` merges every item attribute (role/aria, `data-state`, `tabindex`, `data-radix-collection-item`, `data-slot`, data-variant/size/spacing, classes, Stimulus target/actions) onto the single child (Radix Slot: child props win, class plain-joined slot first; see api-mapping "as_child"); `type="button"` is merged too (toggle:24), exactly like React.

## Structure

Final DOM (after React mount / after Stimulus connect), `type: "single"`, `variant: "outline"`, `default_value: "italic"`, defaults otherwise:

```html
<div role="radiogroup" dir="ltr" data-slot="toggle-group" data-variant="outline" data-spacing="0"
     class="group/toggle-group flex w-fit items-center gap-[--spacing(var(--gap))] rounded-md data-[spacing=default]:data-[variant=outline]:shadow-xs"
     tabindex="0" style="outline: none; --gap: 0;" data-controller="chadcn--toggle-group" ...>
  <button type="button" role="radio" aria-checked="false" data-state="off" aria-label="Toggle bold"
          data-slot="toggle-group-item" data-variant="outline" data-spacing="0" class="<Item classes>"
          tabindex="-1" data-radix-collection-item="">...children</button>
  <button type="button" role="radio" aria-checked="true" data-state="on" ...>...</button>
  ...
</div>
```

### Part `ToggleGroup` (`data-slot="toggle-group"`)

Radix: `RovingFocusGroup.Root asChild` (rf:36-131) slotted onto `Primitive.div` (tg:113-123); with `roving_focus: false` just `Primitive.div` (tg:123).
- tag `div` (or the `as_child` element).
- `role="radiogroup"` for single (tg:28), `role="toolbar"` for multiple (tg:32); caller `role:` wins (spread after, scenario `api__role-override`).
- `dir="ltr" | "rtl"`: ALWAYS present, value of `use_direction(dir)` (tg:111-112).
- `data-slot="toggle-group"`.
- `data-variant` / `data-size`: the given value (`"outline"`, `"sm"`...), OMITTED when `nil` (React drops `undefined`).
- `data-spacing`: always, the formatted `spacing` (default `"0"`).
- `class` = `cn("group/toggle-group flex w-fit items-center gap-[--spacing(var(--gap))] rounded-md data-[spacing=default]:data-[variant=outline]:shadow-xs", class)` (verbatim, tg.tsx). Note: `data-[spacing=default]` never matches a numeric spacing; it is copied unchanged anyway (shadcn-port R2).
- `style`: Radix's `{ outline: "none" }` (rf:104) merged by Slot with shadcn's `{ "--gap": spacing }` -> `style="outline: none; --gap: <spacing>;"`. A caller `style:` REPLACES shadcn's `--gap` declaration (shadcn spreads `{...props}` after `style={...}`) and is appended after `outline: none;`. With `roving_focus: false` there is no `outline: none` (only `--gap`, or the caller style).
- `tabindex` (roving only): `"0"` when at least one item is focusable (not effectively disabled), `"-1"` when none is (`focusableItemsCount === 0`, rf:100) or transiently while Shift+Tab leaves the group (`isTabbingBackOut`, rf:64, 88, 100, 126). Server renders the post-mount value. Absent with `roving_focus: false`.
- `data-orientation`: only when `orientation:` is given AND roving is on (rf:101). No `aria-orientation` (ToggleGroup never sets it).
- NOT rendered on the root: `type`, `value`, `defaultValue`, `disabled`/`data-disabled`, `loop`, `rovingFocus` (all destructured, tg:25, 38-44, 101-109).
- Caller `**attrs` (`id`, `aria-label`, `data-*`, `title`) pass through.
- Children: exactly the block, in order.
- Known oracle quirk (`as_child` on the root): shadcn renders `<ToggleGroupContext.Provider>` INSIDE `<ToggleGroupPrimitive.Root>` (tg.tsx:32-47), so with `asChild` Radix Slot clones the Provider (which ignores props) instead of the caller element; React drops every root attribute (`data-slot="toggle-group"`, `role`, `dir`, `tabindex`, `style`, classes) and only the items render slots. The port intentionally merges the root attributes onto the child (the Stimulus controller lives on the root). Registered in `deviations/toggle-group.json`; scenario `api__as-child-root` was removed because it can never match the oracle (React 3 slots vs Phlex 4).

### Part `ToggleGroupItem` (`data-slot="toggle-group-item"`)

Radix: `Collection.ItemSlot` (col, adds `data-radix-collection-item=""`, col:38) > `RovingFocusGroup.Item asChild` (rf:133-211, `Primitive.span` slotted) > `ToggleGroupItemImpl` > `Toggle` `Primitive.button` (toggle:21-36). With `roving_focus: false`: `Toggle` only (tg:147).
- tag `button` (or the `as_child` element), `type="button"` (toggle:24; caller `type:` wins).
- single: `role="radio"`, `aria-checked="true" | "false"`, NO `aria-pressed` (tg:155 `"aria-pressed": void 0` overrides toggle:25 via the buttonProps spread, toggle:28).
- multiple: `aria-pressed="true" | "false"`, no role (native button).
- `data-state="on" | "off"` (toggle:26), `on` iff the item value is in the group value (tg:133).
- `data-disabled=""` and native `disabled=""` only when effectively disabled (toggle:27, tg:134-135).
- roving only: `tabindex="0" | "-1"` (`0` only for the current tab stop, rf:147, 175). ToggleGroup passes no `defaultCurrentTabStopId`, so initially EVERY item renders `tabindex="-1"` and the root (`tabindex="0"`) is the Tab entry point. The stop becomes the item that last received focus or a focusable mousedown (rf:179-183) and stays after focus leaves. `data-orientation` only when the group has `orientation:` (rf:176). `data-radix-collection-item=""` always (col:38).
- `data-slot="toggle-group-item"`; `data-variant` = group variant || item variant, OMITTED when both `nil`; `data-size` likewise; `data-spacing` = the group's formatted spacing (always present inside a group).
- `class` = `cn(Chadcn::Toggle.variants(variant: group_variant || variant, size: group_size || size), "w-auto min-w-0 shrink-0 px-3 focus:z-10 focus-visible:z-10", "data-[spacing=0]:rounded-none data-[spacing=0]:shadow-none data-[spacing=0]:first:rounded-l-md data-[spacing=0]:last:rounded-r-md data-[spacing=0]:data-[variant=outline]:border-l-0 data-[spacing=0]:data-[variant=outline]:first:border-l", class)` (verbatim, tg.tsx). tailwind-merge resolves `px-3` over the size's `px-*`, `min-w-0` over `min-w-*`, `w-auto`; the `data-[spacing=0]:` variants do not conflict with the unprefixed base tokens. `toggleVariants` is called WITHOUT `className`, then the four arguments go through one `cn`.
- No `value` attribute, no `name`, no hidden input (Radix renders none).
- Caller attrs (`id`, `aria-label`, `aria-invalid`, `title`, `data-*`) win over Radix's.
- Children: the block.

### Server vs Stimulus

The server renders every attribute above for the initial state (R4): `data-state`, `aria-checked`/`aria-pressed`, `tabindex` values, `dir`, `style`. Stimulus (`chadcn--toggle-group`, ONE controller on the root; items are targets, no per-item controller, no `chadcn--toggle` controller on items) updates item `data-state` + `aria-checked`/`aria-pressed`, roving `tabindex`, root `tabindex`. No ids are generated: Radix's roving `useId` tab-stop ids (rf:144) never reach the DOM; the port tracks the tab stop by element reference.

## Behavior

States: per item `on` / `off`; orthogonal `disabled` (item or group). Group value: single = one String or `""`; multiple = Array. `aria-invalid` is a caller attribute (style only).

### Activation (toggle:30-34 -> tg:163-169)

1. Native `click` on an item (unless `event.defaultPrevented` by a consumer handler, primitive:6-12), if not effectively disabled: `pressed = !pressed`.
2. pressed -> `onItemActivate(value)`: single sets the value to it (the previously pressed item turns `off`); multiple appends.
3. unpressed -> `onItemDeactivate(value)`: single sets `""` (nothing pressed; a single group CAN be emptied by clicking the pressed item); multiple removes it.
4. Uncontrolled: update `data-state` and `aria-checked`/`aria-pressed` on every item whose pressed flag changed, then dispatch `value-change`. Controlled: dispatch only.

### Keyboard

Arrow handling is RovingFocusGroup (rf:184-204). Arrows only MOVE focus; they never press (no arrow-select, unlike RadioGroup; no activation on focus, unlike Tabs).

| Key (focus on an item) | Result |
|---|---|
| ArrowRight / ArrowDown | focus the next focusable item, wrapping (`loop: true`) |
| ArrowLeft / ArrowUp | focus the previous focusable item, wrapping |
| with `dir: "rtl"` | ArrowLeft/ArrowRight swap (`getDirectionAwareKey`, rf:222-226); Up/Down unchanged |
| with `orientation: "vertical"` | ArrowLeft/ArrowRight ignored, no preventDefault (rf:229-231) |
| with `orientation: "horizontal"` | ArrowUp/ArrowDown ignored (rf:232-234) |
| Home / PageUp | focus the first focusable item (rf:217-218) |
| End / PageDown | focus the last focusable item (rf:219-220) |
| any of the above with Meta/Ctrl/Alt/Shift | ignored, no preventDefault (rf:192) |
| `loop: false` | at the ends, next/prev does nothing (`slice`, rf:200) |
| Space | native button activation (keyup) -> click -> Activation |
| Enter | native button activation (keydown) -> click -> Activation (Toggle has no keydown handler, toggle:21-36; NOT prevented as in RadioGroup) |
| Tab | leaves the group (non-stop items are `tabindex=-1`) |
| Shift+Tab | sets `isTabbingBackOut` -> root `tabindex="-1"` before default navigation, so focus skips the root and leaves; any `focusout` inside the group (React `onBlur` bubbles) resets it to `"0"` (rf:185-188, 88, 126) |

Mechanics: key handling only when `event.target === event.currentTarget` (rf:189), Shift+Tab checked before that. With a focus intent: `preventDefault()`, candidates = focusable items in DOM order (`querySelectorAll("[data-radix-collection-item]")` inside the group, col:59), reversed for prev/last, rotated after the current index for prev/next (`wrapArray`, rf:247-249), then `setTimeout(() => focusFirst(candidates))` (rf:202, a macrotask). `focusFirst` (rf:238-245) focuses candidates in order until `document.activeElement` changes, stopping if it reaches the previously focused element. Item `mousedown`: if not focusable, `preventDefault()`; else the item becomes the tab stop (rf:179-182). Item `focus` (any cause) makes it the tab stop (rf:183).

With `roving_focus: false`: no key handling at all; items keep native tab order (each enabled item is a Tab stop), arrows do nothing.

### Focus entry (rf:105-125)

- Root `mousedown` (bubbling from inside) sets `isClickFocus = true`.
- Root `focus` with `event.target === root`, not click focus, not tabbing back out: dispatch a cancelable, non-bubbling `CustomEvent("rovingFocusGroup.onEntryFocus")` on the root (ToggleGroup adds no listener, never prevented); then focus the first of [first pressed focusable item (`active: pressed`, tg:143), current tab-stop item, ...focusable items in order] (disabled items filtered first, so a disabled pressed item is skipped). `preventScroll: false`. Then `isClickFocus = false` (always).
- Consequences (scenarios): Tab from before the group lands on the pressed item (single) or the FIRST pressed item in DOM order (multiple), else the last tab stop, else the first enabled item; Shift+Tab from after the group lands on the root and is redirected the same way; a fully disabled group has root `tabindex="-1"` and is skipped.
- Programmatic `item.focus()` moves focus and the tab stop only; it never presses.
- Focus ring only on `:focus-visible`; `focus:z-10` applies on any focus (mouse too), lifting the focused item over its neighbor's border at spacing 0.

### Pointer

Plain `click` (not `pointerdown`). Disabled items have `disabled:pointer-events-none` and native `disabled`: no hover, no click (covered statically and by `tab__entry-skips-disabled`/`arrows__skip-disabled`).

### Not applicable

Timers: none (only the `setTimeout(0)` focus hop). No Presence (only `transition-[color,box-shadow]`), no dismissal, no scroll lock, no positioning, no portal, no typeahead, no form bubble input (react-toggle-group renders none).

### Primitives composed

`roving_focus` (orientation/dir/loop key mapping, `setTimeout` focusFirst, tab-stop `tabindex`, root `tabindex` with focusable-count and Shift+Tab back-out, entry focus with click-focus guard and `active` = pressed), `collection` (DOM-ordered items by the `data-radix-collection-item` attribute the oracle renders, honoring disabled), `direction` (reads the root's own `dir`). With `roving_focus: false` the controller does not start `roving_focus`.

Turbo: `disconnect()` releases the roving-focus listeners and pending focus timeouts; `connect()` reconciles the value from the DOM (`data-state` of items) so a cached page restores consistently.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::ToggleGroup` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render ToggleGroup::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::ToggleGroup::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `toggle_group.item` | `ToggleGroup::Item` | `ToggleGroupItem` |


Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Chadcn::Toggle.variants(variant:, size:)` for item classes (registry dependency `toggle`, spec `toggle.md`). Items do NOT render `Chadcn::Toggle` itself (different data-slot, no `chadcn--toggle` controller).
- `Chadcn::Direction` (`Consumer` / `use_direction`) for the root `dir` (spec `direction.md`).
- No icons rendered by the component (manifest `icons: []`). Scenarios use lucide children via `<icon:x>` (`bold`, `italic`, `underline`, `align-left`, `align-center`, `align-right`, `star`, `heart`, `bookmark`), rendered by `Chadcn::Icon` in the harness.

Harness notes (not component deviations):
- Registry examples pass `className="h-4 w-4"` to the icons; the `<icon:x>` syntax cannot carry a className, so scenarios use bare icons on both sides. Computed size is identical: neither class list contains `size-`, so `[&_svg:not([class*='size-'])]:size-4` applies either way.
- `example__toggle-group-spacing*` use caller classes not in the source (`data-[state=on]:*:[svg]:fill-yellow-500`...); the Phlex Tailwind build must scan scenario files so they exist on both sides.

## Deviations

- `as_child` on the `ToggleGroup` root: React drops all root attributes (Context.Provider is the Slot child, tg.tsx:32-47); the port merges them onto the caller element because the Stimulus controller lives on the root. See the "Known oracle quirk" under Part `ToggleGroup`; entry in `deviations/toggle-group.json`. Everything else (item `as_child`, `roving_focus: false`) maps 1:1.
