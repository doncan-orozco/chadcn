# Select (shadcn `select`, tier overlay)

Sources (cited inline): oracle `gems/chadcn/dev/port/oracle/src/select.tsx` (`src:L<n>`), manifest `oracle/manifest/select.json`,
`gems/chadcn/dev/react-shadcn-catalog/node_modules/@radix-ui/react-select@2.3.8/dist/index.mjs` (`sel:L<n>`), `react-popper@1.3.8` (`pop:`),
`react-presence@1.1.11` (`pre:`), `react-dismissable-layer@1.1.20` (`dl:`), `react-focus-scope@1.2.0` (`fs:`), `react-focus-guards@1.1.6` (`fg:`),
`react-collection@1.1.16` (`col:`), `react-direction@1.1.5` (`dir:`), `react-visually-hidden@1.2.12` (`vh:`), `aria-hidden@1.2.6`,
`react-remove-scroll@2.7.2` / `react-remove-scroll-bar`, `@floating-ui/dom@1.8.0` (catalog), `lucide-react@0.577.0`.
Registry examples: `select-demo`, `select-scrollable` (new-york-v4). Stimulus identifier `shadcn--select`.

## API

Every part takes `class:` (merged last through `cn`) and `**attrs` (deep-merged `data:`/`aria:`), and accepts string and symbol options (`size: :sm` == `"sm"`, `position: :popper` == `"popper"`, `side: :top`, `align: :start`, `sticky: :always`, `dir: :rtl`).

```ruby
Components::V2::Select.new(
  value: nil,            # controlled value (String); "" or nil shows the placeholder (sel:L1156-1158)
  default_value: nil,    # uncontrolled initial value
  open: nil,             # controlled open (true/false); nil = uncontrolled
  default_open: false,
  dir: nil,              # "ltr" | "rtl"; nil -> "ltr" (useDirection: prop || DirectionProvider || "ltr", dir:L18-21; NEVER html[dir])
  name: nil, auto_complete: nil, form: nil,   # forwarded to the hidden native <select> (sel:L1128-1149)
  disabled: false,       # disables the trigger (sel:L170) and the native select
  required: nil          # nil -> no aria-required; true/false -> aria-required="true"/"false" (sel:L201) + native required
) { ... }                # renders NO element (Radix Root, sel:L145-163); no class:/attrs (Root takes none)
Components::V2::Select::Trigger.new(size: "default", disabled: false, class: nil, **attrs) { Select::Value ... }
  # size: "default" | "sm" (src:L28, rendered as data-size). as_child: NOT supported (shadcn passes children + Icon to Radix
  # Slot, React.Children.only throws, src:L44-48); raising ArgumentError is acceptable.
Components::V2::Select::Value.new(placeholder: "", class: nil, **attrs) { optional children override the selected text }
  # Radix destructures and DROPS className and style (sel:L244); style is always "pointer-events: none" (sel:L259).
  # The port must accept class: and drop it too (scenario value__classname-dropped).
Components::V2::Select::Content.new(
  position: "item-aligned",   # "item-aligned" | "popper" (src:L55, sel:L308)
  align: "center",            # shadcn default (src:L56) overrides Radix's popper default "start" (sel:L701); ignored in item-aligned (sel:L438-449)
  side: "bottom", side_offset: 0, align_offset: 0, avoid_collisions: true, collision_padding: 10,   # popper only (pop:L103-117; padding 10 = CONTENT_MARGIN, sel:L702)
  collision_boundary: nil,    # CSS selector string(s) instead of React elements
  sticky: "partial", hide_when_detached: false, arrow_padding: 0,                                    # popper only
  force_mount: false,         # keeps the content mounted while closed (sel:L283-289)
  class: nil, **attrs) { items }
Components::V2::Select::Group.new(class: nil, **attrs) { Select::Label + Select::Item }     # as_child: supported (Primitive.div)
Components::V2::Select::Label.new(class: nil, **attrs) { "text" }                            # must be inside a Group (React throws otherwise, sel:L811); as_child: supported
Components::V2::Select::Item.new(value:, disabled: false, text_value: nil, class: nil, **attrs) { children }
  # value: required String. text_value: overrides typeahead text (default: trimmed textContent of ItemText, sel:L829, L849-851). as_child: NOT supported (two children)
Components::V2::Select::Separator.new(class: nil, **attrs)                                    # as_child: supported
Components::V2::Select::ScrollUpButton.new(class: nil, **attrs)   # rendered by Content automatically (src:L73); exported for explicit use inside Content
Components::V2::Select::ScrollDownButton.new(class: nil, **attrs) # rendered by Content automatically (src:L83)
```

Events (dispatched with `this.dispatch` from the controller host, bubbling, prefix `shadcn--select`):

| Radix prop | Event | detail | cancelable | default action |
|---|---|---|---|---|
| `onOpenChange` (Root) | `shadcn--select:open-change` | `{ open }` | no | uncontrolled: state changes; controlled (`open:` given): nothing changes, the caller re-renders |
| `onValueChange` (Root) | `shadcn--select:value-change` | `{ value }` | no | uncontrolled: value changes; controlled (`value:` given): nothing changes |
| `onEscapeKeyDown` (Content) | `shadcn--select:escape-key-down` | `{ originalEvent }` | yes (dl:L92-99) | dismiss |
| `onPointerDownOutside` (Content) | `shadcn--select:pointer-down-outside` | `{ originalEvent }` | yes (dl:L55-58) | dismiss |
| `onCloseAutoFocus` (Content) | `shadcn--select:close-auto-focus` | `{}` | yes (sel:L474-477) | focus the trigger with `preventScroll` |

`onFocusOutside` is always prevented by Select (sel:L485) and `onMountAutoFocus` is always prevented (sel:L471-473): no events. `onKeyDown`, `onClick`, etc. are plain DOM events via `data: { action: ... }`; caller handlers run first and a caller `preventDefault()` skips the Radix handler (`composeEventHandlers`). `ref` has no equivalent.

## Structure

### Closed DOM (in the caller's parent)

Root and Portal render nothing (`select` and the Portal are in `non_rendered_slots`).

1. `button` Select::Trigger (sel:L194-237, src:L35-49), attributes in Radix order:
   `type="button" role="combobox" aria-expanded="false" aria-autocomplete="none" dir="ltr" data-state="closed"`
   `aria-controls` ONLY while open (content id, sel:L199); `aria-required` only when `required` is not nil (sel:L201);
   `disabled=""` + `data-disabled=""` when Root or Trigger disabled (sel:L170, L205-206);
   `data-placeholder=""` when the value is nil or "" (sel:L207); `data-slot="select-trigger" data-size="default|sm"` (src:L36-37); class = src:L39 joined with `class:`.
   In popper mode while the content is mounted the trigger (Popper Anchor, sel:L194) also carries `data-radix-popper-side` / `data-radix-popper-align` (pop:L89-90; ignored by the runner but required).
   Children: the block (normally Select::Value), then the icon: Radix `Icon asChild` puts `aria-hidden="true"` on the lucide svg (sel:L268) -> `svg.lucide.lucide-chevron-down.size-4.opacity-50[aria-hidden=true]` rendered with `Icon("chevron-down", class: "size-4 opacity-50")`.
2. `span` Select::Value: `data-slot="select-value" style="pointer-events: none;"` + attrs (class dropped). Content: the placeholder text when the value is nil/""; otherwise its own block if given; otherwise a COPY of the selected item's children (Radix portals ItemText children into this span, sel:L959, so icons in the item appear here too). An unknown value renders an empty span and NO `data-placeholder`.
3. Hidden native `select` (SelectBubbleInput, sel:L1100-1150) as the next sibling after the block, ONLY when the trigger is inside a `<form>` or `form:` is set (sel:L97, L154-159):
   `<select aria-hidden="true" tabindex="-1" name required disabled autocomplete form style="(VISUALLY_HIDDEN_STYLES, vh:L8-19)">`, children: `<option value="">` when the value shows the placeholder and no item has value "" (sel:L1144), then one `<option value disabled>text</option>` per Item in registration order (sel:L948-951); the current value's option is selected (React `defaultValue`). Value changes write `select.value` and dispatch a bubbling `change` (sel:L1113-1127); a native `change` (autofill) sets the value (sel:L1138); form `reset` restores the initial value (sel:L88-96).

### Open DOM (portaled to `document.body`, `Portal asChild`, no portal wrapper)

Item-aligned (default):
```
body > div[style="display:flex; flex-direction:column; position:fixed; z-index:<content z-index = 50>; min-width; left|right; top|bottom; height; margin:10px 0; min-height; max-height"]   (sel:L669-677, L569-630)
  > div[data-slot=select-content][role=listbox][id][dir][data-state=open][tabindex=-1]   (sel:L489-506, fs:L145)
       style: box-sizing:border-box; max-height:100%; display:flex; flex-direction:column; outline:none; pointer-events:auto (sel:L683-690, L499-506, dl:L147)
       class: src:L64 (no popper tokens)
    > div[data-slot=select-scroll-up-button][aria-hidden=true][style=flex-shrink:0]   ONLY while viewport.scrollTop > 0 (sel:L976-1004, L1059-1065)
        > svg.lucide-chevron-up.size-4[aria-hidden=true]
    > style   (sel:L740-748: `[data-radix-select-viewport]{scrollbar-width:none;-ms-overflow-style:none;-webkit-overflow-scrolling:touch;}[data-radix-select-viewport]::-webkit-scrollbar{display:none}`)
    > div[data-radix-select-viewport=""][role=presentation][class="p-1"][style="position:relative; flex:1 1 0%; overflow:hidden auto"]  (no data-slot, sel:L749-768, src:L74-82)
        > the Content block (groups, items, separators)
    > div[data-slot=select-scroll-down-button][aria-hidden=true][style=flex-shrink:0]  ONLY while it can scroll down (sel:L1012-1039)
        > svg.lucide-chevron-down.size-4[aria-hidden=true]
```
Popper (`position: "popper"`):
```
body > div[data-radix-popper-content-wrapper=""][dir] style: position:fixed; left:0; top:0; transform:translate(x,y) (translate(0,-200%) until placed); min-width:max-content; z-index:50; --radix-popper-transform-origin  (pop:L206-228)
  > div[data-slot=select-content][data-side][data-align][role=listbox][id][dir][data-state][tabindex=-1]   (pop:L240-252)
       style adds --radix-select-content-transform-origin / -available-width / -available-height / --radix-select-trigger-width / -height as var(--radix-popper-*) (sel:L714-726) and the popper vars written by size() (pop:L159-165); animation:none until placed (pop:L250)
       class: src:L64 + src:L66 popper tokens
    > (same children; viewport class "p-1 h-[var(--radix-select-trigger-height)] w-full min-w-[var(--radix-select-trigger-width)] scroll-my-1", src:L76-79)
```
Parts inside the viewport:
- Select::Group: `div[data-slot=select-group][role=group][aria-labelledby=<group id>]` (sel:L803-804; aria-labelledby is set even without a Label).
- Select::Label: `div[data-slot=select-label][id=<group id>]`, class src:L96.
- Select::Item: `div[data-slot=select-item][role=option][aria-labelledby=<text id>][aria-selected][data-state][data-radix-collection-item=""]` (sel:L862-870, col:L50):
  `aria-selected="true"` only when selected AND focused, else `"false"`; `data-state="checked|unchecked"`; `data-highlighted=""` while focused; `aria-disabled="true"` + `data-disabled=""` when disabled; `tabindex="-1"` unless disabled (no tabindex when disabled). Class src:L111.
  Children: `span[data-slot=select-item-indicator]` (class src:L118) containing, only when selected, `span[aria-hidden=true] > svg.lucide-check.size-4` (sel:L969); then ItemText `span[id=<text id>]` (no data-slot, sel:L958) with the block.
- Select::Separator: `div[data-slot=select-separator][aria-hidden=true]`, class src:L137 (sel:L1087).
- Select::ScrollUpButton / ScrollDownButton: as above; class src:L150 / src:L168; explicit instances render where placed (inside the viewport) with the same visibility rule.

### Body while the content is mounted (open, during exit animation, or force_mount)
- `span[data-radix-focus-guard][tabindex=0]` first and last child of body (style outline:none; opacity:0; position:fixed; pointer-events:none) (fg:L14-46).
- `body.style.pointerEvents = "none"` (disableOutsidePointerEvents, sel:L482, dl:L110-127, L147); the content is `pointer-events:auto`.
- Scroll lock: `body[data-scroll-locked="1"]` + react-remove-scroll-bar style (overflow hidden, scrollbar gap as margin-right), wheel/touch scroll blocked outside the content, pinch zoom allowed (sel:L466).
- `aria-hidden="true"` + `data-aria-hidden="true"` on every body child except the content's ancestor chain (and aria-live/script) (`hideOthers(content)`, sel:L338-340).

### Ids
Content id (`aria-controls`, sel:L99), group id (Group `aria-labelledby` = Label `id`, sel:L803-812), item text id (Item `aria-labelledby` = ItemText `id`, sel:L835). Generated on the server from `id:` on the Root or a per-render counter; only the relations matter (runner normalizes ids).

### Server vs Stimulus
- Server renders the closed DOM exactly (trigger attributes, Value text of the selected item, `data-placeholder`, native select when `name:`/`form:` is given or the controller adds it). Root must know the item texts before emitting the Trigger: it captures its block first (items register `value -> children html` and `text_value`) and then emits trigger + value in order.
- The Content markup (wrapper excluded) is rendered inside an inert `<template>` sibling that the controller detaches on `connect()` (see Deviations), so the post-connect DOM equals Radix's (nothing in the document while closed).
- Controller host: the Trigger (`data-controller="shadcn--select"`, values `open`, `default-open`, `value`, `default-value`, `controlled-open`, `controlled-value`, `dir`, `disabled`, `required`, `position`, `side`, `side-offset`, `align`, `align-offset`, `avoid-collisions`, `collision-padding`, `sticky`, `hide-when-detached`, `force-mount`, `content-id`). Portaled nodes are outside the host, so the controller installs listeners on the content node itself; in-content markers use `data-shadcn--select-*` (ignored by the runner).
- Stimulus owns: mounting/unmounting the content, positioning, `aria-controls`/`aria-expanded`/`data-state`, `data-highlighted`/`aria-selected`, indicator and Value updates, the native select sync, focus guards, scroll lock, hideOthers, body pointer-events.

## Behavior

Primitives composed: `portal`, `presence`, `dismissable_layer` (disableOutsidePointerEvents), `focus_scope` (trapped while open, no auto-focus on mount), `focus_guards`, `scroll_lock`, `hide_others`, `positioner` (popper mode only), `collection`, `typeahead`, `ids`, `direction`, `form_bubble_input`. Item-aligned positioning is Select-only logic (lives in the controller or a `select_item_aligned` helper, not floating-ui).

### States
`closed` <-> `open`; value: placeholder (nil/"") | known value | unknown value. Content `data-state="open"` while open; on close it switches to `"closed"` and stays mounted until its CSS exit animation ends (Presence with function children, sel:L289; pre:L36-50, L60-80, L83-100). With no animation (runner default, reduced motion, or `animation-name: none`) it unmounts in the same frame. During the exit the focus trap is off (`trapped: context.open`, sel:L470) but layer, scroll lock and hideOthers stay until unmount. NOTE: this corrects radix-dom-contract "Verified corrections" ("no Presence"): react-select 2.3.8 does use Presence.

### Trigger keyboard (sel:L227-236)
| Key | Closed trigger |
|---|---|
| `Enter`, `Space`, `ArrowDown`, `ArrowUp` | open (preventDefault); typeahead buffer reset (sel:L182-186) |
| printable char (no ctrl/alt/meta) | typeahead on the CLOSED trigger: value changes to the next matching enabled item WITHOUT opening (sel:L174-181, L230) |
| `Space` while the typeahead buffer is not empty | part of the search, does not open (sel:L231) |
| other keys | nothing (Tab moves focus normally) |
Disabled trigger: native `disabled` button, not focusable, no open.

### Content keyboard (sel:L507-525, item L906-920, layer dl:L91-105)
| Key | Effect |
|---|---|
| `ArrowDown` / `ArrowUp` | focus next / previous ENABLED item after the focused one; no loop (sel:L511-523); focus is applied in `setTimeout` |
| `Home` / `End` | first / last enabled item (with scrollTop reset to 0 / scrollHeight for first/last, sel:L349-352) |
| `Enter`, `Space` on an item | select it (`value-change`, then close); `Space` preventDefault; `Space` during typeahead ignored (sel:L910-919) |
| printable char | typeahead: focus next matching enabled item (sel:L407-414) |
| `Tab` / `Shift+Tab` | prevented, nothing happens (sel:L509) |
| `Escape` | `escape-key-down` (cancelable) then close (dl:L92-99) |
Typeahead (sel:L1160-1201): buffer appended per key, reset 1000 ms after the last key (`typeahead_timeout` value, default 1000); repeated single char cycles through items starting with it; single char excludes the current item; matching is case-insensitive `startsWith` on `text_value` or the trimmed text.

### Focus
- On open: no focus on mount (sel:L471-473); once positioned, focus the selected item, or the first enabled item when no item matches the value, falling back to the content (sel:L342-366, L415-436); the focused item scrolls into view (`block: "nearest"`).
- Trap: focus cannot leave while open (fs:L51-90); focus-outside never dismisses (sel:L485).
- On close (Escape, select, outside click, blur, resize): `close-auto-focus` (cancelable) then `trigger.focus({ preventScroll: true })` (sel:L474-477), dispatched in a `setTimeout(0)` after unmount (fs:L106-115).
- Trigger click always focuses the trigger (sel:L210-211).
- Highlight = DOM focus: `data-highlighted`/`aria-selected` follow focus/blur (sel:L872-873).

### Pointer (sel:L210-226, L367-397, L874-905)
- Mouse: opens on `pointerdown` (button 0, no ctrl), `preventDefault` (no focus/selection from the press); records `pageX/pageY`. Touch/pen: opens on `click`.
- Press-drag-release: after a mouse-opened content mounts, a capture `pointerup` on document: movement <= 10px on both axes -> `preventDefault` (the item under the pointer is NOT selected, menu stays open); more -> release outside the content closes; release on an enabled item selects it (item selects on `pointerup` for mouse, on `click` for touch/keyboard).
- `pointermove` over an enabled item focuses it (`preventScroll`); over a disabled item, or `pointerleave` from the focused item, focuses the content (no item highlighted). Disabled items have `pointer-events: none` (class) and ignore select.
- Outside `pointerdown` -> `pointer-down-outside` (cancelable) -> close (not deferred to click, dl:L267-268); body has `pointer-events: none`, so outside elements get no hover/click.
- `contextmenu` on the content is prevented (sel:L494).
- Scroll buttons: `pointerdown` or `pointermove` starts an interval (50 ms) scrolling the viewport by the selected item's height; `pointerleave` stops it; `pointermove` also unhighlights items (sel:L1041-1081). When a button mounts the focused item is scrolled into view (sel:L1055-1058) and item-aligned repositions once (sel:L651-660).

### Other dismissal
`window` `blur` and `resize` close the select (sel:L398-406).

### Positioning
- Item-aligned (sel:L536-697, CONTENT_MARGIN 10): content wrapper `position: fixed`; horizontally the selected item's text is aligned over the Value span (LTR: `left`, RTL: `right`, clamped to [10, innerWidth-10-contentWidth], `min-width` = trigger width + delta); vertically the selected item's middle is aligned with the trigger's middle; if that overflows the top, `top: 0` and the viewport is scrolled (sel:L616-627), else `bottom: 0` (sel:L605-615); `margin: 10px 0`, `min-height` = min(5 items, full height), `max-height` = innerHeight - 20. Expand-on-scroll: after placement, scrolling the viewport grows the wrapper up to the available height (sel:L769-792). `side`/`align`/offset props are ignored; no `data-side`/`data-align`.
- Popper: positioner with Radix middleware order offset(sideOffset, alignOffset) -> shift(mainAxis, limitShift when sticky partial) -> flip -> size (writes `--radix-popper-available-width/height`, `--radix-popper-anchor-width/height`) -> arrow -> transformOrigin -> hide (pop:L147-180); `strategy: fixed`, `autoUpdate`; writes `data-side`/`data-align` with the placed values. Defaults through shadcn/Select: side bottom, align center, sideOffset 0, collisionPadding 10.

### Timers
Typeahead reset 1000 ms; scroll-button autoscroll interval 50 ms; focus moves after `setTimeout(0)`; close auto-focus after `setTimeout(0)`; outside-pointerdown listener installed after `setTimeout(0)` (dl:L292-294).

### Controlled
`open:` given: trigger/Escape/outside/select dispatch `open-change` but the DOM keeps the server state. `value:` given: selection dispatches `value-change` (and closes, if open is uncontrolled) but the indicator/Value/`data-state` keep the server value.

### Cleanup (radix-stimulus R10)
`disconnect()` unmounts the content, releases layer, trap, guards, scroll lock, hideOthers, body pointer-events, autoUpdate, intervals and timers; a Turbo cache snapshot never contains an open select.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Select` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Select::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Select::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `select.content` | `Select::Content` | `SelectContent` |
| `select.group` | `Select::Group` | `SelectGroup` |
| `select.item` | `Select::Item` | `SelectItem` |
| `select.label` | `Select::Label` | `SelectLabel` |
| `select.scroll_down_button` | `Select::ScrollDownButton` | `SelectScrollDownButton` |
| `select.scroll_up_button` | `Select::ScrollUpButton` | `SelectScrollUpButton` |
| `select.separator` | `Select::Separator` | `SelectSeparator` |
| `select.trigger` | `Select::Trigger` | `SelectTrigger` |
| `select.value` | `Select::Value` | `SelectValue` |

Names that shadow a Phlex HTML element inside `Select`'s OWN `view_template` (use `tag(:label)` there, never the bare method): `label`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies
- `Components::V2::Icon` (`chevron-down` in Trigger and ScrollDownButton, `chevron-up` in ScrollUpButton, `check` in the Item indicator), lucide 0.577.0 markup with `aria-hidden="true"`.
- `Components::V2::Base` (`cn`, `merge_attrs`, `render_as_child` for Group/Label/Separator, ids helper).
- No other V2 components; scenario trees use only Select exports and raw `_div`/`_form`/`_button` wrappers.

## Deviations
One, structural and first-paint only, written to `gems/chadcn/dev/port/deviations/select.json`:
- The closed Content is server-rendered inside an inert `<template>` next to the Trigger (React keeps it in a detached DocumentFragment, sel:L285-299). `<template>` content is not part of the document tree (no `[data-slot]` node, no box, no a11y node) and the controller removes the `<template>` element on `connect()`, so the post-connect DOM is identical to Radix. Entry: `{ "reason": "...", "allow_tokens": [], "allow_missing_tokens": [], "api": [], "structure": ["template"] }`.
API: `as_child:` is not offered on Trigger and Item because the React original throws for it (not a deviation, documented above).
