# menubar

Oracle: `gems/phlex-shadcn/dev/port/oracle/src/menubar.tsx` (new-york-v4, `radix-ui` 1.7.0; cited `tsx:<line>`) + `oracle/manifest/menubar.json` (tier `overlay`, no cva, no registry dependencies, icons `CheckIcon`, `ChevronRightIcon`, `CircleIcon`).
Radix sources read (catalog `gems/phlex-shadcn/dev/react-shadcn-catalog/node_modules/@radix-ui/`, line numbers of each package's `dist/index.mjs`): `react-menubar` 1.1.25 (`Mb:`), `react-menu` 2.1.25 (`M:`), `react-roving-focus` (`RF:`), `react-dismissable-layer` 1.1.20 (`DL:`), `react-popper` 1.3.8 (`P:`), `react-collection` 1.1.16, `react-direction` 1.1.5, `react-focus-guards` 1.1.6, `react-focus-scope` 1.2.0, `react-presence` 1.1.11, `react-portal` 1.1.18. Registry example read: `https://ui.shadcn.com/r/styles/new-york-v4/menubar-demo.json` (the only `menubar-*` item in the registry).

The menu half (Content, items, sub menus, typeahead, popper) is `react-menu`, the same code as dropdown-menu and context-menu: everything below that is not marked "menubar-specific" must behave exactly as in `specs/dropdown-menu.md` (same primitives, same controller helpers). The menubar-specific parts are the Root roving group, the Trigger, `Menubar.Menu`, and the Content's close-focus, focus-outside, entry-focus and ArrowLeft/ArrowRight wiring (Mb:33-276).

## API

Namespace `Components::V2::Menubar`. Every option accepts strings and symbols (`side: :top` == `"top"`, `variant: :destructive` == `"destructive"`, `dir: :rtl` == `"rtl"`). `class:` is merged last through `cn` (caller wins); `data:`/`aria:` hashes deep-merge with the part's required attributes; every other key in `**attrs` passes through to the part's element (`id`, `role`, `aria-*`, `data-*`, `style`, `title`...). `as_child:` is `false | tag symbol | V2 component instance` and uses `Components::V2::Base#render_as_child` (Radix Slot merge, api-mapping.md) on every part that is a Radix `Primitive` (all parts below except `Menubar::Menu`, `Menubar::Portal`, `Menubar::Sub`, and `Menubar::Shortcut`, which is a plain `span` in the oracle, tsx:196-210).

| React export | Ruby call (kwargs with defaults) | Notes / source |
|---|---|---|
| `Menubar` | `Components::V2::Menubar.new(value: nil, default_value: nil, loop: true, dir: nil, as_child: false, class: nil, **attrs) { ... }` | `div role="menubar"` (Mb:86). `value:` non-nil = controlled: the server renders the menu whose value equals it open; user actions only dispatch `value-change` (Mb:47-52 `useControllableState`). `default_value:` initial uncontrolled value (nil == `""` == every menu closed, Mb:50). `loop:` default `true` (Mb:41): wraps both the trigger roving focus and the Content ArrowLeft/ArrowRight menu switching. `dir:` `"ltr" \| "rtl"`; nil -> `"ltr"` (`useDirection(dir)` reads the prop or a DirectionProvider, never `html[dir]`, Mb:45). `dir` is consumed, NOT rendered on the root (Mb:42 and RF:47 destructure it). Hosts the `shadcn--menubar` controller. |
| `MenubarMenu` | `Menubar::Menu.new(value: nil) { ... }` | Renders NO element (manifest `non_rendered_slots`, Mb:95-131 renders `MenuPrimitive.Root`, which is providers only, M:60-110). `value:` String identifying this menu for the root `value`; nil -> an auto value from a per-render counter (Mb:97-98 `useId`), never written to the DOM. `modal` is forced `false` (Mb:124) and is not an option (`MenubarMenuProps` is only `value`/`children`). Unknown kwargs raise `ArgumentError`. |
| `MenubarTrigger` | `Menubar::Trigger.new(disabled: false, as_child: false, class: nil, **attrs) { ... }` | `<button type="button" role="menuitem">` (Mb:152-163). Caller `id:` wins over the generated id (Mb:164 spreads `triggerProps` after `id`), while Content keeps `aria-labelledby` pointing at the generated trigger id, exactly as Radix. Classes tsx:57-60 verbatim. |
| `MenubarPortal` | `Menubar::Portal.new(force_mount: false, container: nil) { ... }` | Renders NO element (Mb:196-200 -> M:122-126). `container:` is a CSS selector (React takes a DOM node; no Ruby form, api-mapping `ref` row); default `document.body`. shadcn's `Content` already wraps itself in a Portal (tsx:74); an explicit Portal is meaningful only around `SubContent` (then the sub is portaled instead of rendered in place). |
| `MenubarContent` | `Menubar::Content.new(side: "bottom", side_offset: 8, align: "start", align_offset: -4, avoid_collisions: true, collision_padding: 0, collision_boundary: nil, sticky: "partial", hide_when_detached: false, update_position_strategy: "optimized", arrow_padding: 0, loop: false, force_mount: false, as_child: false, class: nil, **attrs) { ... }` | `align`/`align_offset`/`side_offset` defaults are shadcn's (tsx:68-70; Radix's own MenubarContent also defaults `align = "start"`, Mb:204); the rest are Radix defaults (P:103-113, M:186). `side`: `top right bottom left`; `align`: `start center end`; `sticky`: `partial always`; `update_position_strategy`: `optimized always`; `collision_padding`: Integer or Hash `{ top:, right:, bottom:, left: }` (missing keys 0, P:125); `collision_boundary`: CSS selector or array of selectors (P:126). Always portaled (tsx:74). |
| `MenubarGroup` | `Menubar::Group.new(as_child: false, class: nil, **attrs) { ... }` | `div role="group"` (Mb:277-283 -> M:382-387). No classes in the oracle (tsx:30-34). |
| `MenubarLabel` | `Menubar::Label.new(inset: nil, as_child: false, class: nil, **attrs) { ... }` | `div` (M:388-393). `inset:` nil -> no `data-inset`; `true` -> `data-inset="true"`; `false` -> `data-inset="false"` (tsx:173 `data-inset={inset}`). Classes tsx:175-176. |
| `MenubarItem` | `Menubar::Item.new(variant: "default", inset: nil, disabled: false, text_value: nil, as_child: false, class: nil, **attrs) { ... }` | `variant:` `"default" \| "destructive"`, rendered verbatim as `data-variant` (tsx:93,103; not validated, like React). `inset:` rule as Label (tsx:102). `text_value:` overrides the typeahead text (M:451,469). Classes tsx:105-106. Selecting dispatches cancelable `select`. |
| `MenubarCheckboxItem` | `Menubar::CheckboxItem.new(checked: false, disabled: false, text_value: nil, as_child: false, class: nil, **attrs) { ... }` | `checked:` `true \| false \| "indeterminate"` (M:508; shadcn passes it through, tsx:126). Controlled only, like Radix (no `defaultChecked`): the port never flips it; it dispatches `checked-change`. Classes tsx:123-124. |
| `MenubarRadioGroup` | `Menubar::RadioGroup.new(value: nil, as_child: false, class: nil, **attrs) { ... }` | `div role="group"` (M:532-538). Controlled only (no `defaultValue` in Radix). |
| `MenubarRadioItem` | `Menubar::RadioItem.new(value:, disabled: false, text_value: nil, as_child: false, class: nil, **attrs) { ... }` | `value:` required String (M:542); checked iff `value == RadioGroup value` (M:544). Classes tsx:148-149. |
| `MenubarSeparator` | `Menubar::Separator.new(as_child: false, class: nil, **attrs)` | `div role="separator" aria-orientation="horizontal"` (M:588-601). Classes tsx:190. |
| `MenubarShortcut` | `Menubar::Shortcut.new(class: nil, **attrs) { ... }` | Plain `span` (tsx:196-210). Classes tsx:204-205. |
| `MenubarSub` | `Menubar::Sub.new(open: nil, default_open: false) { ... }` | Renders NO element (Mb:343-353 -> M:611-643: Popper root + providers). `open:` non-nil = controlled; `default_open:` initial (Mb:346-351). Unknown kwargs raise `ArgumentError`. |
| `MenubarSubTrigger` | `Menubar::SubTrigger.new(inset: nil, disabled: false, text_value: nil, as_child: false, class: nil, **attrs) { ... }` | Block content followed by the chevron icon (tsx:236-237). Caller `id:` wins (M:675). Classes tsx:231-232. |
| `MenubarSubContent` | `Menubar::SubContent.new(side_offset: 0, align: "start", align_offset: 0, avoid_collisions: true, collision_padding: 0, collision_boundary: nil, sticky: "partial", hide_when_detached: false, update_position_strategy: "optimized", arrow_padding: 0, loop: false, force_mount: false, as_child: false, class: nil, **attrs) { ... }` | `side` is NOT an option: forced `"right"` (ltr) / `"left"` (rtl) (M:768). `align` default `"start"` (M:754). shadcn passes no offsets -> Radix 0 (tsx:242-258). Rendered in place inside the parent Content unless wrapped in `Menubar::Portal`. Classes tsx:250-251 verbatim. |

Not exported by shadcn, so not part of the API: `MenubarArrow`, `MenubarItemIndicator` (used internally by CheckboxItem/RadioItem, tsx:130,154).

### Events (`this.dispatch`, prefix `shadcn--menubar`, all `bubbles: true`)

| Event | Dispatched on | `detail` | Cancelable | Radix equivalent |
|---|---|---|---|---|
| `value-change` | Menubar root element | `{ value }` (the open menu's value, `""` when all close) | no | `Menubar.onValueChange` (Mb:47-52, Mb:59-73) |
| `open-change` | SubTrigger | `{ open }` | no | `MenubarSub.onOpenChange` (Mb:346-352) |
| `select` | the item element | `{}` | yes: `preventDefault()` keeps the menu open (M:405-416) | `onSelect` on Item/CheckboxItem/RadioItem |
| `checked-change` | CheckboxItem | `{ checked }` (next = `indeterminate ? true : !checked`, M:519) | no; fires even when `select` was prevented (M:520) | `onCheckedChange` |
| `value-change` | RadioItem (bubbles through RadioGroup) | `{ value }` (M:555) | no; fires even when `select` was prevented | `RadioGroup.onValueChange` |
| `escape-key-down` | Content / SubContent | `{ originalEvent }` | yes: prevents dismissal (DL:91-99) | `onEscapeKeyDown` |
| `pointer-down-outside` | Content / SubContent | `{ originalEvent }` | yes | `onPointerDownOutside` |
| `focus-outside` | Content / SubContent | `{ originalEvent }` | yes (the port then prevents it itself when the target is a menubar trigger, Mb:228-232) | `onFocusOutside` |
| `interact-outside` | Content / SubContent | `{ originalEvent }` | yes (prevents dismissal; the Content's "interacted outside" flag is set only when not prevented, Mb:233-235 composed after the caller) | `onInteractOutside` |
| `open-auto-focus` | Content | `{}` | yes: content is not focused (M:293-296) | `onOpenAutoFocus` |
| `close-auto-focus` | Content | `{}` | yes: the menubar focus-return logic (Mb:220-227) is skipped, so focus is not moved to the trigger | `onCloseAutoFocus` |

The two `value-change` events are told apart by `event.target` (`[data-slot=menubar]` vs `[data-slot=menubar-radio-item]`); the content lives in `body`, so a listener on the root element only ever receives the root's event. Content in the body is outside any caller controller element: callers listen globally (`data-action="shadcn--menubar:select@document->foo#bar"`) or on the item element. `onClick`, `onPointerDown`... are plain DOM events (`data: { action: }`) composed before the port's own handlers, as Radix `composeEventHandlers` does (caller first; a caller `preventDefault()` on a Trigger `pointerdown`/`keydown` suppresses the open, Mb:166-187; on an Item `click` it suppresses selection, M:424).

## Structure

### Elements per part (post-connect DOM; attribute order irrelevant)

| Part | Tag | `data-slot` | Attributes (source) |
|---|---|---|---|
| Menubar | `div` (or `as_child` element) | `menubar` | `role="menubar"` (Mb:86), `data-orientation="horizontal"` (RF:101 via Mb:81), `tabindex="0"`, or `"-1"` when no trigger is focusable (all disabled) or while Shift+Tab is leaving (RF:100), `style="outline: none"` (RF:104). No `dir`, no `aria-orientation`. Classes tsx:15-18 verbatim. |
| Menu | none | (`menubar-menu` never reaches the DOM) | - |
| Portal | none | (`menubar-portal` never reaches the DOM) | - |
| Sub | none | (`menubar-sub` never reaches the DOM: Mb:343-353 passes only `open/onOpenChange/children` to `MenuPrimitive.Sub`, which renders providers only, M:622-642) | - |
| Trigger | `button` (or the `as_child` element) | `menubar-trigger` | `type="button"`, `role="menuitem"`, `id`, `aria-haspopup="menu"`, `aria-expanded="true\|false"`, `aria-controls=<content id>` ONLY while open, `data-state="open\|closed"`, `data-highlighted=""` while it has DOM focus, `data-disabled=""` + `disabled=""` when disabled (Mb:153-163), `tabindex="0"` when it is the roving tab stop else `"-1"` (RF:175), `data-orientation="horizontal"` (RF:176); `data-radix-collection-item` and, while its content is placed, `data-radix-popper-side/align` (P:89-90; ignored by the runner). Classes tsx:57-60. |
| Content | `div` inside `div[data-radix-popper-content-wrapper]` | `menubar-content` | `role="menu"`, `aria-orientation="vertical"`, `data-state`, `data-radix-menu-content=""`, `dir="ltr\|rtl"` (M:325-329, `rootContext.dir` = menubar direction, Mb:125), `id`, `aria-labelledby=<trigger id>`, `data-radix-menubar-content=""` (Mb:213-215), `data-side`, `data-align` (P:241-242), `tabindex="0"` (`"-1"` when it has no focusable item or while Shift+Tab is leaving, RF:100), `data-orientation="vertical"` (RF:101), `style`: `outline: none` (M:333), `animation: none` until positioned (P:250), and the 5 re-namespaced vars `--radix-menubar-content-transform-origin/available-width/available-height`, `--radix-menubar-trigger-width/height: var(--radix-popper-...)` (Mb:262-272). No body `pointer-events` style (non-modal, see Behavior). Classes tsx:81-82 verbatim (note: there is NO `data-[state=closed]:animate-out` token on Content, only on SubContent). |
| Group | `div` | `menubar-group` | `role="group"`. |
| Label | `div` | `menubar-label` | `data-inset` per the inset rule. |
| Item | `div` (or `as_child` element) | `menubar-item` | `role="menuitem"`, `data-inset` (rule), `data-variant` (always, default `"default"`), `tabindex="-1"` (`"0"` when it is the content's roving tab stop, RF:175), `data-orientation="vertical"`, `data-highlighted=""` while focused, `aria-disabled="true"` + `data-disabled=""` when disabled (M:473-476). |
| CheckboxItem | `div` | `menubar-checkbox-item` | `role="menuitemcheckbox"`, `aria-checked="true\|false\|mixed"`, `data-state="checked\|unchecked\|indeterminate"` (M:512-516), plus the Item attributes (tabindex, data-orientation, data-highlighted, aria-disabled/data-disabled). No `data-variant`/`data-inset`. Children: `span.pointer-events-none absolute left-2 flex size-3.5 items-center justify-center` (always, tsx:129) containing, ONLY when checked or indeterminate (Presence, M:575), `span[data-state]` with `Icon("check", class: "size-4")` (tsx:131; shown for indeterminate too), then the block. |
| RadioGroup | `div` | `menubar-radio-group` | `role="group"`. |
| RadioItem | `div` | `menubar-radio-item` | `role="menuitemradio"`, `aria-checked="true\|false"`, `data-state="checked\|unchecked"` (M:548-552), Item attributes. Indicator span as above (tsx:153) with inner `span[data-state="checked"]` + `Icon("circle", class: "size-2 fill-current")` (tsx:155) only when checked. |
| Separator | `div` | `menubar-separator` | `role="separator"`, `aria-orientation="horizontal"`. Not a roving item. |
| Shortcut | `span` | `menubar-shortcut` | Its text is part of the item's typeahead text (`textContent`, M:461). |
| SubTrigger | `div` | `menubar-sub-trigger` | `role="menuitem"`, `id`, `aria-haspopup="menu"`, `aria-expanded`, `aria-controls=<sub content id>` ONLY while open, `data-state="open\|closed"` (M:670-674), `data-radix-menubar-subtrigger=""` (Mb:362; the Content key handler reads it), `data-inset` (rule), Item attributes. Children: block then `Icon("chevron-right", class: "ml-auto h-4 w-4")` (tsx:237; not mirrored in rtl). |
| SubContent | `div` inside its own popper wrapper | `menubar-sub-content` | Same set as Content (role, aria-orientation, data-state, data-radix-menu-content, `data-radix-menubar-content=""` (Mb:379), dir, data-side, data-align, tabindex, data-orientation, outline, the 5 `--radix-menubar-*` vars, Mb:382-392) with `id` = sub content id and `aria-labelledby` = SubTrigger id (M:763-764). |

### DOM order and what the server renders

Root: the server renders `div[data-slot=menubar]` with its static attributes and, inside it in source order, each Menu's Trigger. Closed content: the Content markup is rendered inside an inert `<template>` immediately after its Trigger (inside the root; `<template>` is `display: none` and its content is a DocumentFragment, so it adds no `[data-slot]` node, no box, no flex gap and nothing to the a11y tree); an un-portaled SubContent likewise sits in a `<template>` right after its SubTrigger. Only controller wiring (`data-shadcn--menubar-*`, an id for lookup) may sit on the template. This is the same mechanism as dropdown-menu (not a deviation).

Open (on open, or initially when the root `value:`/`default_value:` matches the Menu's value, or `force_mount:`): the controller moves the Content into `<div data-radix-popper-content-wrapper dir=<menubar dir> style="position: fixed; left: 0; top: 0; transform: translate(x, y); min-width: max-content; z-index: <computed z-index of the content, 50>; --radix-popper-transform-origin: ...">` (P:204-227) appended to the container (default end of `body`, M:125). At most one menu of a menubar is open at a time (`open = context.value === value`, Mb:103). Focus guards: while any menu content is mounted, `span[data-radix-focus-guard]` is the first and the last child of `body`, ref-counted (`useFocusGuards()` runs in every MenuContentImpl, modal or not, M:253). An un-portaled SubContent's wrapper sits inside the parent Content right after its SubTrigger; a portaled one is appended to the container.

`[data-slot]` order the runner sees (menu open, sub open in place): Menubar, its Triggers, (rest of the page), Content, its descendants in source order with the SubContent after its SubTrigger.

### Server vs Stimulus

Server: every static attribute above (roles, `aria-haspopup`, `aria-orientation`, `data-slot`, `data-variant`, `data-inset`, `data-orientation`, initial `data-state`/`aria-expanded`/`aria-checked`, `data-disabled`/`aria-disabled`/`disabled`, initial `tabindex` (root `0`/`-1`, triggers `-1`, items `-1`), ids). Ids: each Menu computes `trigger_id` and `content_id`, each Sub `sub_trigger_id` and `sub_content_id`, from a per-render counter (no `SecureRandom`); relations matter, not values (runner normalizes). Stimulus (`shadcn--menubar` on the root): open/close, `aria-controls`, popper wrapper + positioning (`data-side`, `data-align`, CSS vars), `data-highlighted` on triggers and items, both roving `tabindex` sets, root and Content `tabindex` 0/-1, focus, typeahead, dismissal, focus guards, presence.

## Behavior

Composes primitives: `portal`, `presence`, `positioner`, `dismissable_layer`, `focus_scope` (not trapped; mount/unmount autofocus only), `focus_guards`, `roving_focus` (twice: horizontal on the root, vertical in each content), `typeahead`, `submenu_grace`, `collection`, `ids`, `direction`. NOT used: `scroll_lock`, `hide_others` (every menubar menu is non-modal, Mb:124 -> M:166-179). One controller `shadcn--menubar` on the root handles all menus and subs.

### States

- Root `value`: `""` (all closed) or one Menu's value. Uncontrolled: user actions set it and dispatch `value-change`. Controlled (`value:` given): user actions only dispatch `value-change`; the DOM stays (Escape on `value: "file"` keeps File open; ArrowRight dispatches `value-change` with the next value and keeps File open).
- Transitions (Mb:59-73): `open(v)` sets value `v` and makes `v` the trigger tab stop; `close()` sets `""`; `toggle(v)` sets `""` if any menu is open, else `v`, and makes `v` the tab stop. A Menu's content requesting close (Escape, outside, select, window blur) calls `close()` (Mb:121-123); a Menu never requests "open" through Radix Menu.
- Trigger `data-state`/`aria-expanded`, SubTrigger `data-state`/`aria-expanded` flip immediately. Content: on close `data-state="closed"`; because its classes have no `animate-out`, Presence unmounts it in the same frame (no exit animation, tsx:81). SubContent has `data-[state=closed]:animate-out` and stays mounted until its exit animation ends.
- Sub `open`: controllable as above; whenever its menu closes, every sub is set closed (M:618-621), including `default_open: true` (open only while its menu is open; on re-open of the menu it starts closed, because the uncontrolled state was set to false).
- `wasKeyboardTriggerOpen` per Menu: set when the trigger handles Enter/Space/ArrowDown (Mb:183-186), cleared whenever that menu is closed (Mb:104-106). It gates entry focus (below).
- Item highlight = DOM focus (`data-highlighted` on focus, removed on blur, M:474, M:497-498); Trigger highlight likewise (Mb:142, 160, 188-189).
- CheckboxItem/RadioItem checked state is controlled only.
- `force_mount: true` on Content keeps it mounted while closed (`data-state="closed"`, still portaled and positioned); its focus-scope mount autofocus still focuses it on mount (M:293-296).

### Keyboard (menubar-specific)

Trigger (Mb:179-187, then roving RF:184-204; the trigger handler runs first because Slot composes the child's handler before the slot's). Disabled triggers ignore keys and are skipped by roving (`focusable: !disabled`, Mb:149):

| Key | Effect |
|---|---|
| `Enter`, `Space` | `toggle(value)`, mark keyboard-open, `preventDefault` |
| `ArrowDown` | `open(value)` (never closes), mark keyboard-open, `preventDefault` |
| `ArrowRight` / `ArrowLeft` (swapped in rtl, RF:222-225) | focus next / previous focusable trigger, wrapping when `loop` (default true); done in a `setTimeout` (RF:202). Does not open anything |
| `Home`, `PageUp` / `End`, `PageDown` | first / last focusable trigger |
| any of the above roving keys with Meta/Ctrl/Alt/Shift | ignored by roving (RF:192) |
| `ArrowUp`, characters | nothing (no typeahead on triggers) |
| `Tab` | leaves the menubar (only one element of the group is tabbable). `Shift+Tab` on a trigger sets "tabbing back out": root `tabindex="-1"` until the root blurs (RF:185-188, 100, 126), so focus goes to the element before the menubar |

Root focus (RF:108-125): when the root itself receives focus not caused by a mousedown on it, entry focus goes to the first of [current tab stop trigger, ...focusable triggers] (no `onEntryFocus` handler at the menubar level). So Tab into the menubar lands on the first enabled trigger, or on the trigger that was the last tab stop. While Tab moves forward out of the menubar the root keeps `tabindex="0"`; a later Shift+Tab from after the menubar lands directly on the tab-stop trigger.

Content / SubContent: identical to dropdown-menu's table (M:334-351, RF:184-217, M:432-444, M:740-744, M:784-792): ArrowDown/ArrowUp (no wrap unless Content `loop: true`), Home/PageUp, End/PageDown, the content-element first/last keys (`ArrowDown/PageUp/Home` -> first, `ArrowUp/PageDown/End` -> last, M:38-40, 343-350), Enter/Space select (Space ignored while typing ahead), SubTrigger opens on Enter/Space/ArrowRight (ArrowLeft in rtl), ArrowLeft (ArrowRight in rtl) inside a SubContent closes it and focuses its SubTrigger, Tab/Shift+Tab prevented, typeahead. Plus the menubar handler on the Content (Mb:239-261), which runs for keydowns anywhere inside the Content including an in-place SubContent, and even when an inner handler prevented the event (`checkForDefaultPrevented: false`):

| Key (ltr; mirrored in rtl) | Where | Effect |
|---|---|---|
| `ArrowRight` | on a SubTrigger | nothing from the menubar (the sub opens) |
| `ArrowRight` | anywhere else, including items inside a SubContent | `open(next enabled trigger's value)`, wrapping when `loop`; with `loop: false` and no next trigger, nothing |
| `ArrowLeft` | inside a SubContent | nothing from the menubar (the sub closes) |
| `ArrowLeft` | in the root Content (items and SubTriggers alike) | `open(previous enabled trigger's value)`, wrapping when `loop` |

"Enabled" = triggers not `disabled` (Mb:251), in DOM order. Switching menus this way does NOT set keyboard-open on the new menu, so its Content is focused but no item is (entry focus prevented, Mb:236-238); a following ArrowDown focuses its first item (content-element key).

`Escape` (topmost dismissable layer, DL:90-107): in the Content, `close()` and focus returns to the trigger; in a SubContent it closes the whole menu (`rootContext.onClose()`, M:780-783), same focus return.

Keyboard modality: as dropdown-menu (capture `keydown` on document sets "using keyboard", next `pointerdown`/`pointermove` clears it, M:67-80).

### Focus

- Open: the Content is focused (`preventScroll`) by its focus-scope mount autofocus (M:293-296) unless `open-auto-focus` is prevented. Entry focus then moves to the first enabled item only when BOTH the menu was opened from its trigger by Enter/Space/ArrowDown (Mb:236-238) AND the keyboard is in use (M:318-320). Pointer open, hover switch, ArrowLeft/ArrowRight switch, initial `value`/`default_value`: the Content is focused, no item highlighted.
- SubContent open: focused only when the keyboard is in use (M:772-775).
- Pointer over items, disabled items, leaving items, grace area: as dropdown-menu (M:254-282, M:479-496).
- Close (Content unmount, Mb:220-227; the menubar always `preventDefault`s the focus-scope return): focus goes to the trigger only if no menu of the menubar is open any more AND the content had no outside interaction (pointerdown outside or focus outside, including focus moving to another menubar trigger) since it opened. So: Escape and select -> trigger; outside click/focus -> no move; switching menus -> no move (the new content takes focus). If `close-auto-focus` is prevented by the caller, nothing moves focus (the focused node is removed, focus falls to `body`).
- Not trapped (non-modal). Focus moving outside the Content dismisses it (DL:310-330 `focusin`), EXCEPT when the target is inside one of the menubar's triggers (Mb:228-232: prevented, the menu stays open; that still counts as an outside interaction for the close-focus rule).

### Pointer (menubar-specific)

- Trigger `pointerdown`, button 0, no Ctrl, not disabled: `open(value)` (Mb:166-171). When the menu was closed it `preventDefault`s, so the trigger does not take focus and the new Content gets it. When it was already open nothing changes in the trigger handler, the native focus goes to the trigger, and the Content's dismissable layer treats the press as outside (the trigger is not inside the layer): the menu closes and focus stays on the trigger (no focus return because of the outside interaction). Net effect: click toggles. Right click / Ctrl+click: nothing on the trigger; with a menu open, the outside pointerdown still closes it.
- Trigger `pointerenter` while any menu of the menubar is open and this one is not: `open(value)` and focus this trigger (Mb:172-178), then the new Content's mount autofocus takes focus. There is no disabled guard in this handler: reproduce the listener exactly and let the browser decide whether a disabled `<button>` receives `pointerenter`.
- Press on a trigger, drag, release on an item selects it (M:425-431).
- Items, SubTrigger (100 ms open timer, 300 ms grace polygon), `whenMouse` filtering (M:857-859): as dropdown-menu.
- `pointerdown` outside any open content (not on a trigger): dismisses on `pointerdown` (`deferPointerDownOutside` false, DL:32), the outside listener being attached `setTimeout(0)` after mount (DL:292-294). No body `pointer-events: none` (non-modal), so any outside element is clickable.
- `window` `blur` closes the open menu (M:81-88).

### Dismissal, modality, presence

Every menubar menu is non-modal (Mb:124): no focus trap, no `body` `pointer-events: none`, no `aria-hidden` on siblings, no scroll lock (M:166-179). Escape, outside pointerdown, focus outside (except onto a menubar trigger), select and window blur close the menu. Presence: Content opens with `animate-in fade-in-0 zoom-in-95` + `slide-in-from-*` by `data-side` (tsx:81) and closes with no exit animation (no `animate-out` token); SubContent animates both ways (tsx:251). With reduced motion / the runner's no-motion style both unmount in the same frame. The popper sets `animation: none` until positioned (P:250).

### Positioning (`positioner`, floating-ui, strategy `fixed`)

Same middleware stack as dropdown-menu (P:147-181): `offset({ mainAxis: side_offset + arrowHeight(0), alignmentAxis: align_offset })`, `shift({ mainAxis: true, crossAxis: false, limiter: sticky == "partial" ? limitShift() : none })` and `flip()` when `avoid_collisions`, `size` (writes `--radix-popper-available-width/height`, `--radix-popper-anchor-width/height`), `transformOrigin` (wrapper `--radix-popper-transform-origin`), `hide({ strategy: "referenceHidden" })` only when `hide_when_detached` (its boundary is the explicit `collision_boundary` or, when none, floating-ui's default clipping ancestors, P:169-180). Shared `padding: collision_padding`, `boundary`, `altBoundary: boundary given` (P:128-133). `autoUpdate` (`animationFrame` when `update_position_strategy: "always"`), released on close. Anchor = the Trigger (Mb:151 `MenuPrimitive.Anchor asChild`). shadcn defaults place the Content 8 px below the trigger, start-aligned and shifted 4 px toward the start (`align_offset: -4`). The wrapper carries `dir` (P:227) so floating-ui's RTL detection matches. SubContent anchors on its SubTrigger with side `right` (ltr) / `left` (rtl), flipping when it does not fit.

### Timers (Stimulus values, Radix defaults)

`sub-open-delay` 100 ms (M:693), `pointer-grace-timeout` 300 ms (M:723), `typeahead-timeout` 1000 ms (M:244), outside-listener attach delay 0 ms (DL:292), trigger roving focus move in `setTimeout(0)` (RF:202), typeahead focus move in `setTimeout(0)` (M:246-248).

### Scenario notes

Menus that a scenario opens through `defaultValue`/`value` carry explicit `MenubarMenu value` props (auto values are not addressable). Outside interactions use a neutral `_button[data-testid=outside]` sibling (non-modal: the page stays clickable) or `html` at a fixed position. `framed(...)` trees wrap the menubar between `_button[data-testid=before]` and `_button[data-testid=outside]` to observe Tab entry and exit. Disabled items are exercised through keyboard and typeahead (they are `pointer-events-none`). The registry example is reproduced verbatim (trailing spaces before `MenubarShortcut` included); a keyboard tour and per-menu opens are added under `example__menubar-demo-*`.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Phlex::Shadcn::Menubar` MUST `yield self` from `view_template`; `Phlex::Shadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Menubar::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Phlex::Shadcn::Menubar::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `menubar.portal` | `Menubar::Portal` | `MenubarPortal` |
| `menubar.menu` | `Menubar::Menu` | `MenubarMenu` |
| `menubar.trigger` | `Menubar::Trigger` | `MenubarTrigger` |
| `menubar.content` | `Menubar::Content` | `MenubarContent` |
| `menubar.group` | `Menubar::Group` | `MenubarGroup` |
| `menubar.separator` | `Menubar::Separator` | `MenubarSeparator` |
| `menubar.label` | `Menubar::Label` | `MenubarLabel` |
| `menubar.item` | `Menubar::Item` | `MenubarItem` |
| `menubar.shortcut` | `Menubar::Shortcut` | `MenubarShortcut` |
| `menubar.checkbox_item` | `Menubar::CheckboxItem` | `MenubarCheckboxItem` |
| `menubar.radio_group` | `Menubar::RadioGroup` | `MenubarRadioGroup` |
| `menubar.radio_item` | `Menubar::RadioItem` | `MenubarRadioItem` |
| `menubar.sub` | `Menubar::Sub` | `MenubarSub` |
| `menubar.sub_trigger` | `Menubar::SubTrigger` | `MenubarSubTrigger` |
| `menubar.sub_content` | `Menubar::SubContent` | `MenubarSubContent` |

Names that shadow a Phlex HTML element inside `Menubar`'s OWN `view_template` (use `tag(:menu)` there, never the bare method): `menu`, `label`, `sub`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Components::V2::Icon`: `check` in CheckboxItem (`size-4`, tsx:131), `circle` in RadioItem (`size-2 fill-current`, tsx:155), `chevron-right` in SubTrigger (`ml-auto h-4 w-4`, tsx:237); lucide version of the catalog.
- `Components::V2::Base` (`render_as_child`, `merge_attrs`, `cn`).
- No other V2 component. Shares the menu controller helpers and primitives with `dropdown-menu` and `context-menu` (behavior must stay identical for Content/items/subs).

## Deviations

None. The closed-state `<template>` is invisible to the `[data-slot]` tree, layout and accessibility (see Structure) and `container:` as a selector is the api-mapping translation of a DOM reference, so no `deviations/menubar.json` is written.

Tooling note (not a port deviation): the manifest's `non_rendered_slots` lists `menubar-menu` and `menubar-portal` but not `menubar-sub`, although `MenubarPrimitive.Sub` renders no element (Mb:343-353). The port renders nothing for `Menubar::Sub`; `oracle_extract.rb` `NO_DOM` must also match `MenubarPrimitive.Sub` or G1 will report a false `G1_SLOT_MISSING menubar-sub`.
