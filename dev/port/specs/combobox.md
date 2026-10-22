# Combobox (shadcn `combobox`, tier third_party, Base UI)

Sources (cited inline): oracle `gems/chadcn/dev/port/oracle/src/combobox.tsx` (`src:L<n>`), manifest `oracle/manifest/combobox.json` (source_sha 4f88734887ed6928),
and the REAL Base UI source the oracle wraps, `gems/chadcn/dev/react-shadcn-catalog/node_modules/@base-ui/react@1.9.0/` (NOT Radix, NOT cmdk/Popover):
`combobox/root/AriaCombobox.mjs` (`root:L`), `combobox/root/ComboboxRoot.mjs` (`rootw:L`), `combobox/input/ComboboxInput.mjs` (`input:L`), `combobox/trigger/ComboboxTrigger.mjs` (`trigger:L`),
`combobox/clear/ComboboxClear.mjs` (`clear:L`), `combobox/popup/ComboboxPopup.mjs` (`popup:L`), `combobox/positioner/ComboboxPositioner.mjs` (`pos:L`), `combobox/portal/ComboboxPortal.mjs` (`portal:L`),
`combobox/list/ComboboxList.mjs` (`list:L`), `combobox/item/ComboboxItem.mjs` (`item:L`), `combobox/item-indicator/ComboboxItemIndicator.mjs` (`ind:L`), `combobox/group/ComboboxGroup.mjs` (`group:L`),
`combobox/group-label/ComboboxGroupLabel.mjs` (`glabel:L`), `combobox/empty/ComboboxEmpty.mjs` (`empty:L`), `combobox/collection/ComboboxCollection.mjs` (`coll:L`), `combobox/value/ComboboxValue.mjs` (`value:L`),
`combobox/chips/ComboboxChips.mjs` (`chips:L`), `combobox/chip/ComboboxChip.mjs` (`chip:L`), `combobox/chip-remove/ComboboxChipRemove.mjs` (`chiprm:L`), `combobox/utils/*` (`parts:L`, `dismiss:L` = ComboboxInternalDismissButton, `press:L` = handleInputPress),
`internals/filter.mjs` (`filter:L`), `internals/resolveValueLabel.mjs` (`label:L`), `internals/useAnchorPositioning.mjs` (`anchor:L`), `internals/useInitialLiveRegionTextMutation.mjs` (`live:L`),
`floating-ui-react/components/FloatingFocusManager.mjs` (`ffm:L`), `floating-ui-react/utils/markOthers.mjs` (`mark:L`), `floating-ui-react/hooks/useListNavigation.mjs` (`nav:L`), `floating-ui-react/hooks/useTypeahead.mjs` (`ta:L`), `floating-ui-react/hooks/useDismiss.mjs` (`dis:L`).
Every DOM fact below was also verified by rendering the oracle (the catalog's `combobox.tsx` + Base UI 1.9.0) in Chromium and dumping the DOM after each step.
Registry examples: the new-york-v4 `combobox-demo`, `combobox-popover`, `combobox-dropdown-menu`, `combobox-responsive` items are Popover + Command demos that never render a `Combobox*` export (they belong to the command/popover scenario sets); the examples that exercise this component are the shadcn Base UI showcase `r/styles/base-nova/combobox-example.json` (Basic, Sides, Disabled, Disabled Items, Invalid, With Clear, With Groups, With Groups and Separator, Form, Large List, Auto Highlight, Input Addon, In Popup, Multiple, Multiple Disabled, Multiple Invalid, Multiple No Remove), each one an `example__combobox-*` scenario. Stimulus identifier `shadcn--combobox`.

## API

Every part takes `class:` (merged last through `cn`) and `**attrs` (deep-merged `data:`/`aria:`, R6), accepts string and symbol options (`side: :inline_end` == `"inline-end"`, `align: :end`, `auto_highlight: "always"`/`:always`, `filter: :contains`), and keeps the React export nesting (`ComboboxInput` -> `Combobox::Input`). Non-scalar defaults are frozen constants (Ruby 3.2 renders array/hash literals differently in the public API snapshot): there are none in this API (every collection default is `nil`).

```ruby
Chadcn::Combobox.new(                 # Base UI Combobox.Root (rootw:L12-28, root:L49-89); renders NO Base UI element (see Structure: host + hidden inputs)
  items: nil,                # Array of String | Hash (value:/label:, extra keys allowed) | groups [{ value:, items: [...] }] (root:L258, label:L6-16).
                             # nil = items are rendered as static children: Base UI then does NO filtering and reports the list as empty (root:L265-270, list:L43, empty:L33)
  multiple: false,           # selectionMode "multiple" (rootw:L23)
  value: nil,                # controlled selection (String/Hash; Array when multiple); nil = uncontrolled
  default_value: nil,        # initial selection (multiple: nil means [], root:L219)
  input_value: nil, default_input_value: nil,   # controlled / initial text of the input (root:L237-251; single mode default = label of the selection)
  open: nil, default_open: false,               # controlled / initial popup state (root:L252-257)
  name: nil, form: nil, auto_complete: nil,     # hidden input(s) for native forms (root:L1196-1297); auto_complete = Base UI `autoComplete` -> `formAutoComplete`
  id: nil,                   # Base UI `id`: becomes the input id and the prefix of item ids (`<id>-<index>`) and of the hidden input (`<id>-hidden-input`)
  disabled: false, read_only: false, required: false,
  auto_highlight: false,     # false | true (highlight first match while typing) | "always" (root:L211-216)
  keep_highlight: false,     # Base UI keepHighlight (nav resetOnPointerLeave = !keep_highlight, root:L1079)
  highlight_item_on_hover: true, loop_focus: true, open_on_input_click: true,
  modal: false,              # true: backdrop and page scroll lock; focus is not trapped (recorded deviation) (pos:L78, L102-105)
  limit: -1,                 # max rendered matches (root:L276-322)
  submit_on_item_click: false,                  # requestSubmit() on the form after an item press (item:L113-116)
  filter: "fuzzy",           # "fuzzy" (primitives/scorer.js) | "contains" (Base UI Intl.Collator contains, filter:L9-33) | nil (no filtering = Base UI filter={null}, root:L224-226). See Third-party
  locale: nil,               # Intl.Collator locale for "contains"
  item_to_string_label: nil, item_to_string_value: nil, item_equal_to_value: nil  # Ruby callables evaluated on the server (Base UI itemToStringLabel/itemToStringValue/isItemEqualToValue)
) { |combobox| ... }         # yields self (DX helpers)
Chadcn::Combobox::Input.new(disabled: false, show_trigger: true, show_clear: false, class: nil, **attrs) { optional extra InputGroup children }   # src:L55-90
Chadcn::Combobox::Trigger.new(as_child: false, disabled: false, class: nil, **attrs) { children }   # src:L22-40; as_child = Base UI `render` (Radix Slot merge, Base#render_as_child)
Chadcn::Combobox::Clear.new(disabled: false, class: nil, **attrs)                                       # src:L42-53 (also rendered by Input when show_clear:)
Chadcn::Combobox::Value.new(placeholder: nil) { |value_or_values| ... }                                 # src:L18-20, value:L14-41; renders NO element
Chadcn::Combobox::Content.new(side: "bottom", side_offset: 6, align: "start", align_offset: 0, anchor: nil, class: nil, **attrs) { ... }   # src:L92-127
  # side: "top" | "bottom" | "left" | "right" | "inline-start" | "inline-end" (anchor:L100-107); align: "start" | "center" | "end";
  # anchor: CSS selector string of the positioning anchor (React: element/ref from useComboboxAnchor); also sets data-chips="true" (src:L117)
Chadcn::Combobox::List.new(class: nil, **attrs) { |item| ... }      # src:L129-140; block called once per (filtered) root item when items: is set, plain block otherwise (list:L55-62)
Chadcn::Combobox::Item.new(value:, disabled: false, class: nil, **attrs) { children }   # src:L142-167; value: any item (String/Hash)
Chadcn::Combobox::Group.new(items: nil, class: nil, **attrs) { ... }       # src:L169-177; items: the group's items for a nested Collection (group:L45-50)
Chadcn::Combobox::Label.new(class: nil, **attrs) { "text" }               # src:L179-193 (Base UI GroupLabel)
Chadcn::Combobox::Collection.new { |item| ... }                           # src:L195-199; renders NO element (coll:L16-27)
Chadcn::Combobox::Empty.new(class: nil, **attrs) { "No items found." }    # src:L201-212
Chadcn::Combobox::Separator.new(class: nil, **attrs)                      # src:L214-225
Chadcn::Combobox::Chips.new(class: nil, **attrs) { Combobox::Value block } # src:L227-242
Chadcn::Combobox::Chip.new(show_remove: true, class: nil, **attrs) { text } # src:L244-273
Chadcn::Combobox::ChipsInput.new(class: nil, **attrs)                     # src:L275-287
```

- `useComboboxAnchor` (src:L289-291) is a React ref hook: no Ruby class; its role is played by `Content.new(anchor: "<selector>")` (deviation, API).
- `Combobox::Input` is exactly the shadcn composition (src:L67-89): `InputGroup(class: cn("w-auto", class))` > Base UI input rendered as `InputGroup::Input(disabled:)` (caller attrs such as `placeholder:`, `id:`, `name:`, `required:`, `aria-invalid:` go to that input) > `InputGroup::Addon(align: "inline-end")` > [`InputGroup::Button(size: "icon-xs", variant: "ghost", as_child: Combobox::Trigger, "data-slot": "input-group-button", class: "group-has-data-[slot=combobox-clear]/input-group:hidden data-pressed:bg-transparent", disabled:)` when `show_trigger`] + [`Combobox::Clear(disabled:)` when `show_clear`] > block. `disabled:` of Input is the shadcn prop: it only reaches the rendered `<input disabled>`, the trigger and the clear button; it does NOT disable the Base UI input state (no `data-disabled` on the input, src:L58,L69; verified).
- `Combobox::Value` block: single mode receives the selected item (nil when none), multiple mode the Array of selected items (value:L28-29); without a block it renders the selected label (multiple: labels joined by ", ", label:L107-117) or `placeholder` when nothing is selected (value:L32-33).
- Items: a String is its own label and form value; a Hash uses `label` (else `value`) as label and `value` as form value when it has both keys (label:L43-65); other values serialize like `serializeValue` (JSON). `item_to_string_label`/`_value` override. Equality: `item_equal_to_value` or Ruby `==` (Base UI default is `Object.is`, root:L79; deviation, API).
- Events (dispatched from the host with `this.dispatch`, bubbling, prefix `shadcn--combobox`; Base UI `eventDetails.cancel()` maps to `preventDefault()`, R5):

| Base UI prop | Event | detail | cancelable | default action |
|---|---|---|---|---|
| `onValueChange` (root:L651-663) | `shadcn--combobox:value-change` | `{ value, reason }` | yes | uncontrolled: selection changes; controlled (`value:` given): selection stays, but the single-mode input text is still filled until the popup unmounts (root:L659-662, L742-755) |
| `onOpenChange` (root:L580-650) | `shadcn--combobox:open-change` | `{ open, reason }` | yes | uncontrolled: open state changes; controlled: nothing |
| `onInputValueChange` (root:L502-564) | `shadcn--combobox:input-value-change` | `{ inputValue, reason }` | yes | text changes |
| `onItemHighlighted` (root:L466-501) | `shadcn--combobox:item-highlighted` | `{ value, index, reason }` | no | - |
| `onOpenChangeComplete` (root:L717-718, popup:L59-67) | `shadcn--combobox:open-change-complete` | `{ open }` | no | - |

`reason` strings are Base UI's `REASONS` (`input-change`, `input-clear`, `input-press`, `item-press`, `escape-key`, `outside-press`, `focus-out`, `list-navigation`, `clear-press`, `chip-remove-press`, `close-press`, `none`). Not ported (React-only): `render` other than `Trigger as_child:`, `inline`, `grid`, `virtualized`, `filteredItems`, `filterQuery`, `actionsRef`, `inputRef`, function-valued `filter` (named filters instead), `ref`.

## Structure

### Host and hidden inputs (Root)
Base UI Root renders no element; it renders its children followed by the form inputs (root:L1219-1297). The port wraps them in ONE controller host `<div style="display: contents" data-controller="shadcn--combobox" ...values>` with no `data-slot`, class or other data attributes (deviation, structure), so the compared DOM is the children + inputs:
1. The block (Input / Chips / Trigger, Content).
2. Base hidden input, always: `<input tabindex="-1" aria-hidden="true" value="<serialized single value or ''>">` plus: `id="<root id>-hidden-input"` only when it has no name; `name` = `name:` except in multiple mode (root:L1203); `form`, `autocomplete` (= `auto_complete:`), `disabled`, `required` (`required && !(multiple with a selection)`, root:L1288), `readonly`. Style (exact strings, React order): with a name `clip-path: inset(50%); overflow: hidden; white-space: nowrap; border: 0px; padding: 0px; width: 1px; height: 1px; margin: -1px; position: absolute;` (visuallyHiddenInput), without `... margin: 0px; position: fixed; top: 0px; left: 0px;` (visuallyHidden) (root:L1292). Focusing it focuses the input (or the trigger when the input is inside the popup, root:L1223-1229); a native `change` (autofill) selects the matching item by serialized value or label, case-insensitive (root:L1231-1281).
3. Multiple mode with `name:`: one `<input type="hidden" name value [form] [disabled]>` per selected value, in selection order (root:L1204-1218).
The server renders all of these with the initial values (no-JS and Turbo form submission work); the controller keeps them in sync (`form_bubble_input` semantics: write `value`, bubble `input`/`change`).

### Input (`Combobox::Input`, input outside the popup)
```
div[data-slot=input-group][role=group]  class = InputGroup classes + "w-auto" (+ class:)
  span[role=button][aria-label=Dismiss][style=visuallyHiddenInput]      ONLY while open (dismiss:L14-35, input:L341-343); a click closes (reason close-press)
  input[data-slot=input-group-control]  (InputGroup::Input classes)
  div[data-slot=input-group-addon][role=group][data-align=inline-end]
    button[data-slot=input-group-button]   (the Trigger, see below)            when show_trigger
    button[data-slot=combobox-clear]        (Clear, see below)                 when show_clear and something is selected
  (block)
```
Input attributes (server-rendered at rest, Stimulus updates; role.reference root:L1010-1038, input:L135-150, nav:L493-497):
`autocomplete="off" spellcheck="false" autocorrect="off" autocapitalize="none" role="combobox" aria-expanded="true|false" aria-haspopup="listbox" aria-autocomplete="list"` (`"none"` when read_only); `id` = root id; `value` = input text (single mode: label of the selection); `aria-controls` = List id ONLY while open; `aria-activedescendant` = id of the highlighted item ONLY while open and something is highlighted; `aria-required="true"` when required; `aria-readonly="true" readonly=""` when read_only; `disabled=""` only from Input `disabled:` (render prop). State data attributes (input:L114-121, stateAttributesMapping): `data-popup-open="" data-pressed=""` while open, `data-popup-side="<side>"` while the popup is mounted, `data-list-empty=""` when the filtered list is empty, `data-disabled=""` (Root disabled), `data-readonly=""`. No `name` unless the caller passes one (the base-nova Form example puts `name`/`required` on ComboboxInput: the visible input then submits its text, verified).

Trigger inside the Input = `InputGroup::Button(as_child: Combobox::Trigger)` (src:L73-84): `button[type=button][tabindex=-1][aria-expanded][aria-haspopup=listbox][data-slot=input-group-button][data-variant=ghost][data-size=icon-xs]` (Slot merge: the explicit `data-slot="input-group-button"` wins over `combobox-trigger`, verified), `aria-controls` = List id while open, `data-placeholder=""` while nothing is selected, `data-popup-open data-pressed data-popup-side` while open, `data-disabled="" disabled=""` (Root or Input disabled), `data-readonly`, `data-list-empty` (trigger:L121-129, L133-141). Class: Button ghost + InputGroup::Button icon-xs tokens + `[&_svg:not([class*='size-'])]:size-4` (src:L30) + `group-has-data-[slot=combobox-clear]/input-group:hidden data-pressed:bg-transparent` (src:L79), merged by the as_child rules (api-mapping). Child: `Icon("chevron-down", class: "pointer-events-none size-4 text-muted-foreground", "data-slot": "combobox-trigger-icon")` -> `svg.lucide-chevron-down[aria-hidden=true][data-slot=combobox-trigger-icon]` (src:L34-37).

### Standalone `Combobox::Trigger` (input inside the popup, base-nova "In Popup")
`button[data-slot=combobox-trigger][type=button][tabindex=0][id=<root id>][role=combobox][aria-expanded][aria-haspopup=dialog]` + `aria-controls="<root id>-popup"` while open + the state data attributes above; class `[&_svg:not([class*='size-'])]:size-4` + class:; children: block, then the chevron icon (trigger:L78-87, L133-141). Its block is normally `Combobox::Value`, which renders the selected label as a bare text node (or the placeholder): no element, no `data-slot="combobox-value"` (value:L39-41, verified). The input inside the Content gets a generated id and no outer form wiring.

### Clear (`Combobox::Clear`)
`button[data-slot=combobox-clear][data-variant=ghost][data-size=icon-xs][type=button][tabindex=-1]` + `data-visible=""` while something is selected, `data-popup-open` while open, `data-disabled="" disabled=""`, `data-starting-style`/`data-ending-style` during its mount/unmount transition (clear:L68-73, L83-120); rendered only while a value exists (and through its exit transition), never with nothing selected (clear:L47-54, L121-124). It is `InputGroup::Button(variant: "ghost", size: "icon-xs")` (src:L46) with child `Icon("x", class: "pointer-events-none")` (src:L50). Clicking: clears the text and the selection, clears the highlight, focuses the input (clear:L93-117); mousedown is prevented (no focus steal).

### Chips (multiple mode, `Combobox::Chips` > `Combobox::Value { |values| chips + ChipsInput }`)
- `div[data-slot=combobox-chips]` + `role="toolbar"` only while at least one value is selected (chips:L32-34); class src:L236. mousedown on the container (not on an interactive child) focuses the input and opens (press:L5-21).
- `div[data-slot=combobox-chip][tabindex=-1]` per selected value, in selection order; `aria-disabled="true" data-disabled=""` when Root disabled; `aria-readonly="true"` when read_only (chip:L90-99); class src:L256. Children: the block text, then (show_remove) the remove button.
- `button[data-slot=combobox-chip-remove][data-variant=ghost][data-size=icon-xs][type=button][tabindex=-1][aria-disabled=false]` (`aria-disabled="true" data-disabled=""` when disabled) = `Chadcn::Button(variant: "ghost", size: "icon-xs")` with class `-ml-1 opacity-50 hover:opacity-100` and child `Icon("x", class: "pointer-events-none")` (src:L262-269, chiprm:L74-97).
- `input[data-slot=combobox-chip-input]` with the input ARIA/state attributes above, class `min-w-16 flex-1 outline-none` (+ class:) (src:L280-284); `disabled` when passed.
- New chips after a client-side selection are built from the Value block output: the server renders the Value block once for the current selection (real DOM) and once per item with `[item]` inside inert `<template>` prototypes that stay in the document (deviation, structure).

### Content (portaled; nothing in the document while closed, portal:L24-27)
While mounted (open, or during the exit animation):
```
body > div[data-base-ui-portal][id]                                              (FloatingPortal)
  div[role=presentation][data-base-ui-inert][aria-hidden=true]                   ONLY modal: backdrop, style "position: fixed; inset: 0px; user-select: none; clip-path: polygon(<viewport minus anchor rect>)" (pos:L102-105)
  div.isolate.z-50[role=presentation][data-open|data-closed][data-side][data-align]   (Positioner, pos:L79-98, src:L107-114)
      [data-empty] when the list is empty, [data-anchor-hidden] when the anchor is clipped,
      style: "position: absolute; top: 0px; left: 0px; --available-width; --available-height; --anchor-width; --anchor-height; --transform-origin; transform: translate(x, y)"
             (fixed + opacity 0 until the first placement, anchor:L333-367; pointer-events: none while closing)
    span[data-type=inside][data-base-ui-focus-guard][aria-hidden][tabindex=0]   ONLY when the input is inside the popup (non-modal focus manager)
    div[data-slot=combobox-content][tabindex=-1][data-base-ui-focusable][role=presentation][data-open|data-closed][data-side][data-align][data-chips="true|false"]   (Popup, popup:L68-90)
        [data-empty], [data-starting-style]/[data-ending-style] + style "transition: none" while starting, role="dialog" id="<root id>-popup" when the input is inside the popup
        class src:L119 (+ class:)
      (block: Empty, List, or Input + Empty + List)
    span[data-type=inside][data-base-ui-focus-guard]                             (popup-input mode)
    span[role=button][aria-label=Dismiss][style=visuallyHiddenInput]            ONLY when the input is outside the popup (popup:L113-115)
```
Popup-input mode also inserts after the Trigger `span[data-type=outside][data-base-ui-focus-guard][aria-hidden=true][tabindex=0]`, `span[aria-owns=<portal id>][style="clip-path: inset(50%); position: fixed; top: 0px; left: 0px;"]`, and a second outside guard (FloatingPortal non-modal, verified).
- `div[data-slot=combobox-empty][role=status][aria-live=polite][aria-atomic=true]`, class src:L206; its children render ONLY while the filtered list is empty (empty:L33-41); the element itself always stays (live region). When it mounts with text, a U+2060 word joiner is appended to its last text node for 200 ms (live:L8-58).
- `div[data-slot=combobox-list][role=listbox][tabindex=-1][id]` + `aria-multiselectable="true"` (multiple), `aria-readonly="true"` (read_only), `data-empty=""` when empty, `aria-activedescendant` when the input is inside the popup (list:L63-93); class src:L134.
- `div[data-slot=combobox-item][role=option][id=<root id>-<visible index>][aria-selected=true|false]` + `data-selected=""` when selected, `data-highlighted=""` when highlighted, `data-disabled="" aria-disabled="true"` when disabled; no tabindex (item:L104-127); class src:L151. Children: block, then `span[data-slot=combobox-item-indicator][data-selected][aria-hidden=true]` (class src:L160) containing `Icon("check", class: "pointer-events-none size-4 pointer-coarse:size-5")`, rendered ONLY for selected items (ind:L18-26). Ids are re-numbered by visible position after every filter change.
- `div[data-slot=combobox-group][role=group][aria-labelledby=<label id>]` (group:L32-40); `div[data-slot=combobox-label][id][aria-hidden=true]` (glabel:L33-39), class src:L187.
- `div[data-slot=combobox-separator][role=presentation][data-orientation=horizontal]`, class src:L221 (ListboxSeparator, verified).
- `Combobox::Collection` and `Combobox::Value` render no element (coll:L25-27, value:L39-41): `combobox-collection` / `combobox-value` never reach the DOM although the manifest lists them in `data_slots` (the extractor reads the JSX; Base UI drops the prop). The port keeps the strings in its source (G1) but must not render them (G2 NODE_COUNT).
- Static children without `items:` (Base UI allows it): no filtering, the Popup/List carry `data-empty`, the Input `data-list-empty` and Empty shows its text permanently (root:L269-270, list:L43; verified in `static__children-without-items`).

### While open (outside the popup)
`aria-hidden="true"` on every element outside the kept set (popup, dismiss spans, the reference input, aria-live regions) that is not an ancestor of a kept element (e.g. the InputGroup addon, other page content), and `data-base-ui-inert=""` on the outermost non-kept body children (ffm:L335-354, mark:L60-110); restored on close. Elements already `aria-hidden` stay untouched.

### Server vs Stimulus, ids
Server: host, Input/Chips/Trigger with rest attributes, Value text/chips, hidden inputs, `data-placeholder`, the Content markup inside an inert `<template>` (mounted into `div[data-base-ui-portal]` on open via `template_mount`, removed on close; deviation, structure), per-item markers `data-shadcn--combobox-*` (ignored by the runner) carrying each item's serialized value, label and disabled state so the controller can filter without a server round trip. Stimulus: open state, positioning, highlight/`aria-activedescendant`, filtering (detach/re-attach item and group nodes, re-number ids), selection/indicator/chips/hidden inputs/input text, dismiss spans, focus guards, aria-hidden/inert marking, live-region marker. Ids: root id from `id:` or a per-render counter (input id, `<id>-<n>` items, `<id>-hidden-input`, `<id>-popup`); List, label and portal ids from the counter. The runner normalizes ids, only relations matter.

## Behavior

Primitives composed: `template_mount`, `presence`, `dismissable_layer`, `scroll_lock` (modal only), `hide_others` (aria-hidden only: the `data-aria-hidden` marker is not added, Base UI has none), `anchor_positioner` (Base UI anchor positioning, below), `typeahead` (closed trigger), `ids`, `scorer` (filter). The controller itself creates the portal container (`body > div[data-base-ui-portal]`) and the Base UI focus guards.

### States
`closed` <-> `open` (mounted while open and during the exit animation: `data-open`/`data-closed`, `data-starting-style` on enter, `data-ending-style` on exit; unmount after `animationend`/`transitionend`, same frame without animation; R6). Selection: none | value | values. Highlight: none | index into the visible list (virtual focus: DOM focus stays on the input, `aria-activedescendant` points at the item, nav:L493-497). Query: the trimmed input text; in single mode the query is ignored while it equals the selected label and was not edited since opening (root:L259-262).

### Opening
- Mouse down on the input (button 0) opens (`useClick` mousedown-only, no toggle, root:L1043-1051); clicking the input again keeps it open. Focus alone (Tab) does NOT open.
- Mouse down on the trigger toggles (opens / closes), focuses the input and prevents the default (trigger:L109-113, L169-184).
- Enter/Space (a click with no pointer press) on the trigger toggles the popup and moves focus to the search field (useClick:105-120).
- `ArrowDown` / `ArrowUp` on the closed input open with the first / last item highlighted (or the selected item when there is one) (nav:L548-563; `focusItemOnOpen` "auto", root:L1077).
- Typing a non-empty value opens (input:L195-257); without `auto_highlight` the highlight is cleared on every keystroke, with it the first match is highlighted (root:L551-553, L835-853).
- `default_open:`/`open:` render open on connect without moving focus.
- Mouse down on the Chips container opens and focuses the chips input (press:L5-21); `ArrowDown`/`ArrowUp` on a focused chip open (chip:L76-82).
- Disabled Root: nothing opens; read_only opens and browses but never selects (root:L1040-1042).

### Keyboard (input focused, open; root:L1068-1107, input:L258-332, list:L79-92, nav:L303-411)
| Key | Effect |
|---|---|
| `ArrowDown` / `ArrowUp` | next / previous item, disabled items INCLUDED (`disabledIndices` empty, root:L1082); past the end the highlight goes to none (input), then wraps (`loop_focus` + allowEscape, root:L1075-1076); from none `ArrowUp` goes to the last item |
| `Home` / `End` | move the caret to the start / end of the text (stopEvent), never the highlight (input:L272-285, nav:L345) |
| `Enter` | highlighted item: "click" it (select; disabled/read_only items do nothing); nothing highlighted: close and let the form submit (input:L317-331) |
| `Escape` | close (escape-key). With the popup NOT mounted: clear the text and the selection (single nil, multiple []) (input:L286-296) |
| `Tab` | focus moves on; leaving to another element closes (focus-out) and restores the text (ffm:L300-320) |
| `Backspace` with empty text (chips) | removes the last chip (input:L299-307) |
| `ArrowLeft` at caret 0 (chips, `ArrowRight` in RTL) | focus the last chip (input:L122-134, L308-311) |
| `Ctrl`/`Shift`/`Alt`/`Meta` + key | skipped by the input's own handling (Enter, Escape, Home/End, chip keys; input:L259-261) |
Focused chip (chip:L42-111): `ArrowLeft`/`ArrowRight` previous/next chip (out of range: back to the input); `Backspace`/`Delete` remove it and focus the chip now at that index (the previous one when it was last; the input when none left, parts:L32-35); `Enter`/Space: back to the input; `ArrowDown`/`ArrowUp`: open; printable: back to the input (typing continues there). Remove button: click or Enter/Space removes its chip and focuses the input (chiprm:L66-96).
Closed standalone Trigger (single, popup-input mode): printable keys run a typeahead over the item labels that SELECTS the match without opening, 750 ms buffer reset (trigger:L92-107, ta:L25); `ArrowDown`/`ArrowUp` open and focus the inner input (trigger:L211-216).

### Pointer
- Hover (mousemove) highlights the item (`highlight_item_on_hover`); leaving an item for a non-item clears the highlight unless `keep_highlight` (nav:L425-447).
- Item press: `pointerdown`/`mousedown` are prevented (the input keeps focus, item:L128-141); `click` selects (item:L142-147); a `mouseup` on a highlighted item selects when the press started elsewhere (drag-select, item:L148-155).
- Outside press closes (`outsidePressEvent` mouse "sloppy" = pointerdown, touch "intentional" = click, root:L1052-1067, dis:L222); presses on the trigger, the clear button, the chips container or the input are not "outside". After an outside close in single mode the text is restored to the selected label.

### Selection (root:L664-710, L651-663)
- Single: select, close, input text = label, hidden input = serialized value, Trigger/InputGroup loose `data-placeholder`; selecting the selected item again keeps it. Clearing the text by editing (input empty, input outside the popup) clears the selection (input:L239-248).
- Multiple: toggles the item, keeps the popup open and the highlight on it; when the text was a non-empty filter: closes (input outside the popup) and clears the text (root:L686-702). Chips and hidden inputs follow the selection order.
- On unmount after a close (root:L717-756): highlight cleared; single with the input outside: text re-synced to the selected label (or `""`); multiple: typed text cleared; popup-input mode: inner input cleared, focus returns to the Trigger (popup:L97-102).
- Controlled `value:`: events fire, the selection stays; the single input text shows the pressed label until unmount, then the controlled label again (verified, `selected__controlled-value`).

### Filtering
Query from the input; `items:` filtered by `filter:` (see Third-party) with `limit:`; groups keep their order and are dropped when no item matches (label and separator included, root:L272-302); visible items keep Base UI's order for `"contains"`, scorer rank for `"fuzzy"`. The list scrolls back to the top on typed input (root:L535-550). Empty result: Empty children rendered, `data-empty` on Popup/Positioner/List, `data-list-empty` on Input/Trigger, the popup stays open. Escape with no items and no Empty part lets the event propagate (root:L588-590).

### Focus
The input keeps DOM focus the whole time (virtual focus). Input outside the popup: focus manager "modal" but untrapped (Tab leaves and closes), no initial focus, no return focus (popup:L95-103, ffm:L139-145). Input inside the popup: on open focus the inner input (touch: the popup), focus guards, on close return focus to the Trigger.

### Positioning (anchor:L50-330; NOT the Radix popper stack)
Anchor = `anchor:` element, else the Trigger (input inside the popup), else the input element (shadcn uses its own InputGroup, so the anchor is the `<input>`, pos:L59). Placement from side/align (`inline-start`/`inline-end` resolve by direction, data-side keeps the logical name). Middleware: `offset({ mainAxis: side_offset, crossAxis: align_offset, alignmentAxis: align_offset })` -> for align center: `shift` then `flip`, otherwise `flip` then `shift` -> `size` (writes `--available-width/height` px and the device-pixel-snapped `--anchor-width/height`) -> `arrow` (fake element) -> `transformOrigin` (writes `--transform-origin`: aligned edge `0%`/`100%` or arrow center on the cross axis, `-side_offset px` / `calc(100% + side_offset px)` on the side axis) -> `hide` (`data-anchor-hidden`). collisionPadding 5 (flip padding 5 + 1 + 1 bias toward the preferred side), collisionBoundary clipping ancestors, flip `fallbackAxisSide: "none"` (dropdown collision avoidance: flips top/bottom only, pos:L41), `lazyFlip`: the first placed side is kept while the list resizes during the same open. strategy `absolute` (fixed + opacity 0 until positioned), `autoUpdate` (ancestor scroll, element resize, layout shift). `positioner.js` today implements the Radix stack (`--radix-popper-*`, wrapper div): this Base UI behavior (these vars on the positioner element itself, this middleware order, no wrapper) is implemented by the additive primitive `anchor_positioner.js` (recorded exception); `positioner.js` is unchanged.

### Modal (`modal: true`)
Backdrop element above, scroll lock (body), focus is not trapped (recorded deviation), outside presses on the backdrop close.

### Timers
Live-region marker 200 ms; closed-trigger typeahead reset 750 ms; Clear unmount after its exit transition; Presence on close.

### Cleanup (radix-stimulus R10)
`disconnect()` and `turbo:before-cache` unmount the popup, release markers/aria-hidden, guards, scroll lock, autoUpdate, timers; hidden inputs keep the current value so a Turbo snapshot restores what the user selected. With a Turbo 8 morph refresh the controller stays connected, so `turbo:before-cache` resets while connected.

## Third-party

The oracle wraps `@base-ui/react` 1.9.0 (`Combobox.*`, plus its Floating UI fork). **No third-party JavaScript is added** (maintainer constraint of the adoption epic): the behavior above is re-implemented in the `shadcn--combobox` Stimulus controller on the shared primitives, with `@floating-ui/dom` (already pinned for `positioner.js`) as the only positioning math. Mapping of Base UI parts to the port: Root -> host + hidden inputs; Input -> `Combobox::Input` (InputGroup composition) / `ChipsInput`; Trigger, Clear, Chips, Chip, ChipRemove, List, Item, ItemIndicator, Group, GroupLabel (`Combobox::Label`), Separator, Empty -> same DOM as above; Portal + Positioner + Popup -> `Combobox::Content` (template mounted into a `data-base-ui-portal` div); Value, Collection -> no element.

Filtering: Base UI's default filter is `Intl.Collator(locale, { usage: "search", sensitivity: "base", ignorePunctuation: true })` substring matching that keeps the source order (filter:L9-33). The port's default `filter: "fuzzy"` uses `primitives/scorer.js` (`rank()`: fold case and diacritics, subsequence match, 0 = hidden, ranked by score, ties in source order; empty query keeps everything in order). Differences: the fuzzy filter also matches subsequences ("nxt" finds "Next.js"), ignores whitespace in the query, does not ignore punctuation the way the collator does, and ranks prefix/word-boundary matches first instead of keeping the source order. `filter: "contains"` reproduces Base UI exactly; `filter: nil` disables filtering. No parity scenario observes the difference: every typed query in `scenarios/combobox.json` ("re", "kit", "NUX", "ux", "a", "lond", "zz") yields the same visible set in the same order with both algorithms, so this is a documented note, not a deviation.

Oracle driving (harness prerequisites, infra): Base UI renders lists through render functions and positions against refs, which a JSON tree cannot express. The scenarios use two conventions that `Harness.tsx` and `ShadcnParity::TreeRenderer` must both implement (until then these scenarios are HARNESS_ERROR, see the receipt blockers):
- `_Each` node: when a node's children contain `{ "c": "_Each", "children": [template...] }`, the node receives a render-function child `(arg) => children'` where the `_Each` node is replaced by its template rendered once per element of `arg` (Array, e.g. `ComboboxValue` in multiple mode) or once with `arg` (e.g. `ComboboxList`/`ComboboxCollection` items, groups). Inside a template, a string prop value or text child equal to `"$item"` or `"$item.<path>"` is replaced by that element (or its property; missing -> undefined/empty). Nested `_Each` nodes bind their own argument. React keys: index + serialized element. Phlex side: the same node becomes a block taking `|item|` / `|values|`.
- `"$ref:<css selector>"` prop value: React gets a ref-like object whose `current` is `document.querySelector(selector)` read lazily; Phlex passes the selector string (`Content anchor:`).

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Combobox` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Combobox::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Combobox::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `combobox.input` | `Combobox::Input` | `ComboboxInput` |
| `combobox.content` | `Combobox::Content` | `ComboboxContent` |
| `combobox.list` | `Combobox::List` | `ComboboxList` |
| `combobox.item` | `Combobox::Item` | `ComboboxItem` |
| `combobox.group` | `Combobox::Group` | `ComboboxGroup` |
| `combobox.label` | `Combobox::Label` | `ComboboxLabel` |
| `combobox.collection` | `Combobox::Collection` | `ComboboxCollection` |
| `combobox.empty` | `Combobox::Empty` | `ComboboxEmpty` |
| `combobox.separator` | `Combobox::Separator` | `ComboboxSeparator` |
| `combobox.chips` | `Combobox::Chips` | `ComboboxChips` |
| `combobox.chip` | `Combobox::Chip` | `ComboboxChip` |
| `combobox.chips_input` | `Combobox::ChipsInput` | `ComboboxChipsInput` |
| `combobox.trigger` | `Combobox::Trigger` | `ComboboxTrigger` |
| `combobox.value` | `Combobox::Value` | `ComboboxValue` |

Names that shadow a Phlex HTML element inside `Combobox`'s OWN `view_template` (use `tag(:input)` there, never the bare method): `input`, `label`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Chadcn::InputGroup`, `InputGroup::Input`, `InputGroup::Addon(align: "inline-end")`, `InputGroup::Button(size: "icon-xs", variant: "ghost", as_child:)` (Input, Trigger, Clear; src:L9-14, L46, L67-89).
- `Chadcn::Button(variant: "ghost", size: "icon-xs")` (ChipRemove, src:L264).
- `Chadcn::Icon`: `chevron-down` (Trigger), `x` (Clear, ChipRemove), `check` (ItemIndicator); `search` only in scenarios (input addon example; the base-nova example uses `globe`, replaced to avoid a catalog change).
- `Chadcn::Base` (`cn`, `merge_attrs`, `render_as_child`, ids, `normalize_option`).
- JavaScript: Stimulus + primitives listed under Behavior, including `scorer.js`; Base UI anchor positioning is implemented by the additive primitive `anchor_positioner.js` (recorded exception); `positioner.js` is unchanged.

## Deviations

Written to `gems/chadcn/dev/port/deviations/combobox.json` (structure and API only, no class-token allowance):
- Structure: one `display: contents` controller host around the Root children and hidden inputs (Base UI Root renders no element); the closed Content shipped in an inert `<template>` mounted on open (Base UI Portal renders nothing while unmounted); Value-block chip prototypes and the single-mode Value text marker shipped as inert `<template>` markers that stay in the document (read on every selection change, so a Turbo snapshot can rebuild chips and the label). None carries a `data-slot`, class or box.
- API: `Content anchor:` is a CSS selector string (React: element/ref, `useComboboxAnchor` has no Ruby equivalent); Trigger `as_child:` stands for Base UI `render`; `item_to_string_label`/`item_to_string_value`/`item_equal_to_value` are Ruby callables evaluated on the server and item equality defaults to `==` instead of `Object.is`; function-valued `filter` is replaced by the named filters `"fuzzy"`/`"contains"`/`nil` and callbacks by the events listed in API; `inline`, `grid`, `virtualized`, `filteredItems`, `filterQuery`, `actionsRef`, `inputRef` are not ported.
