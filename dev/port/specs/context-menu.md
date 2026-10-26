# context-menu

Oracle: `dev/port/oracle/src/context-menu.tsx` (new-york-v4, `radix-ui` 1.7.0) + `oracle/manifest/context-menu.json` (tier `overlay`, no cva, no registry dependencies). Registry example: `context-menu-demo` (the only `context-menu-*` item in `r/styles/new-york-v4/registry.json`).
Radix sources read (catalog `dev/react-shadcn-catalog/node_modules/@radix-ui/`): `react-context-menu` 2.3.8 (cited `CM:<line>`), `react-menu` 2.1.25 (`M:`), `react-dismissable-layer` 1.1.20 (`DL:`), `react-focus-scope` 1.2.0 (`FS:`), `react-popper` 1.3.8, `react-roving-focus` 1.1.20, `react-focus-guards` 1.1.6, `react-presence` 1.1.11, `react-portal` 1.1.18; `lucide-react` 0.577.0. Line numbers are of each package's `dist/index.mjs` (types from `dist/index.d.mts`, cited `CM.d:`).

Menu internals (items, checkbox/radio, sub menus, typeahead, roving focus, pointer grace, presence, popper middleware) are the SAME `react-menu` code that DropdownMenu uses. Everything in `dev/port/specs/dropdown-menu.md` sections "Keyboard (inside Content / SubContent)", "Typeahead", "Pointer" (items and SubTrigger), "Positioning" middleware and "Timers" applies verbatim here and must be implemented by the SAME primitives; this spec lists only what ContextMenu changes or adds, plus the full API/Structure for this component.

## API

Namespace `Chadcn::ContextMenu`. Every option accepts strings and symbols (`variant: :destructive` == `"destructive"`, `dir: :rtl` == `"rtl"`). `class:` is merged last through `cn` (caller wins) on parts that have oracle classes; on parts with NO oracle classes (Trigger, Group, RadioGroup) shadcn does not call `cn` (tsx:18, 26, 49 spread `className` raw), so the caller's `class` is emitted VERBATIM (no tailwind-merge; scenario `trigger__class-passthrough` keeps both `rounded-md` and `rounded-full`). `data:`/`aria:` hashes deep-merge; every other key in `**attrs` passes through (`id`, `role`, `aria-*`, `data-*`, `style`, `title`...). `as_child:` is `false | tag symbol | Chadcn component instance` through `Chadcn::Base#render_as_child` (Radix Slot merge) on every Radix `Primitive` part (all except `ContextMenu`, `Portal`, `Sub`, `Shortcut`).

| React export | Ruby call (kwargs with defaults) | Notes / source |
|---|---|---|
| `ContextMenu` | `Chadcn::ContextMenu.new(open: nil, dir: nil, modal: true) { ... }` | Renders NO element (`non_rendered_slots`; CM:21-53). There is NO `default_open:`: Radix Root props are only `open`, `onOpenChange`, `dir`, `modal` (CM.d:12-18; `defaultProp: false`, CM:37). `open:` non-nil = controlled: user actions only dispatch `open-change`. `open: true` before any interaction anchors the content at the viewport point (0, 0) (initial `point` state, CM:61; Radix logs a dev warning, CM:27-31). `modal:` default `true` (CM:22). `dir:` `"ltr" \| "rtl"`, nil -> `"ltr"` (`useDirection`, never `html[dir]`). Unknown kwargs raise `ArgumentError`. |
| `ContextMenuTrigger` | `ContextMenu::Trigger.new(disabled: false, as_child: false, class: nil, **attrs) { ... }` | `<span>` (CM:84-111). Hosts the `chadcn--context-menu` controller. `style:` is merged AFTER `-webkit-touch-callout: none` (caller wins, CM:91). |
| `ContextMenuPortal` | `ContextMenu::Portal.new(force_mount: false, container: nil) { ... }` | Renders NO element (CM:115-119, M:122-126). `container:` CSS selector (DOM-reference translation, as in dropdown-menu). Only meaningful around `SubContent` (shadcn `Content` portals itself, tsx:100). |
| `ContextMenuContent` | `ContextMenu::Content.new(align_offset: 0, avoid_collisions: true, collision_padding: 0, collision_boundary: nil, sticky: "partial", hide_when_detached: false, update_position_strategy: "optimized", arrow_padding: 0, loop: false, force_mount: false, as_child: false, class: nil, **attrs) { ... }` | `side`, `side_offset`, `align` are NOT options: the type omits them (CM.d:30 `Omit<MenuContentProps, 'onEntryFocus' \| 'side' \| 'sideOffset' \| 'align'>`) and the code forces `side: "right", sideOffset: 2, align: "start"` after the caller props (CM:131-136). Passing them raises `ArgumentError`. Other defaults are Radix popper/menu defaults (same as dropdown-menu spec). Always portaled (tsx:100). |
| `ContextMenuGroup` | `ContextMenu::Group.new(as_child: false, class: nil, **attrs) { ... }` | `div role="group"` (M:382-387). |
| `ContextMenuLabel` | `ContextMenu::Label.new(inset: nil, as_child: false, class: nil, **attrs) { ... }` | `div` (M:388-393). `inset:` nil -> no `data-inset`; `true` -> `data-inset="true"`; `false` -> `data-inset="false"` (tsx:196 `data-inset={inset}`). |
| `ContextMenuItem` | `ContextMenu::Item.new(variant: "default", inset: nil, disabled: false, text_value: nil, as_child: false, class: nil, **attrs) { ... }` | `variant:` `"default" \| "destructive"`, default `"default"` (tsx:116), always rendered as `data-variant`. Selecting dispatches cancelable `select`. |
| `ContextMenuCheckboxItem` | `ContextMenu::CheckboxItem.new(checked: false, disabled: false, text_value: nil, as_child: false, class: nil, **attrs) { ... }` | `checked:` `true \| false \| "indeterminate"` (M:508). Controlled only (no `defaultChecked` in Radix). |
| `ContextMenuRadioGroup` | `ContextMenu::RadioGroup.new(value: nil, as_child: false, class: nil, **attrs) { ... }` | `div role="group"` (M:532-538). Controlled only. |
| `ContextMenuRadioItem` | `ContextMenu::RadioItem.new(value:, disabled: false, text_value: nil, as_child: false, class: nil, **attrs) { ... }` | `value:` required String; checked iff equal to the group value (M:544). |
| `ContextMenuSeparator` | `ContextMenu::Separator.new(as_child: false, class: nil, **attrs)` | `div role="separator" aria-orientation="horizontal"` (M:588-601). |
| `ContextMenuShortcut` | `ContextMenu::Shortcut.new(class: nil, **attrs) { ... }` | Plain `span` (tsx:219-232), no `as_child`. |
| `ContextMenuSub` | `ContextMenu::Sub.new(open: nil, default_open: false) { ... }` | Renders NO element (CM:221-231). Sub DOES have `default_open` (CM.d:69-75). Unknown kwargs raise `ArgumentError`. |
| `ContextMenuSubTrigger` | `ContextMenu::SubTrigger.new(inset: nil, disabled: false, text_value: nil, as_child: false, class: nil, **attrs) { ... }` | Block, then the chevron icon (tsx:73-74). Caller `id:` wins (M:675). |
| `ContextMenuSubContent` | `ContextMenu::SubContent.new(side_offset: 0, align: "start", align_offset: 0, avoid_collisions: true, collision_padding: 0, collision_boundary: nil, sticky: "partial", hide_when_detached: false, update_position_strategy: "optimized", arrow_padding: 0, loop: false, force_mount: false, as_child: false, class: nil, **attrs) { ... }` | `side` forced `"right"` (ltr) / `"left"` (rtl) (M:768), not an option. `align` default `"start"` (M:754; honored at runtime, kept as in dropdown-menu). shadcn passes no `sideOffset` -> 0. Rendered in place inside the parent Content unless wrapped in `ContextMenu::Portal` (the registry demo renders it un-portaled). |

Not exported by shadcn: `ContextMenuArrow`, `ContextMenuItemIndicator` (internal to CheckboxItem/RadioItem).

### Events (`this.dispatch`, prefix `chadcn--context-menu`, all `bubbles: true`)

Same set and semantics as dropdown-menu: `open-change` (`{ open }`, on the Trigger for the root, on the SubTrigger for a sub; CM:35-40, CM:224-229), `select` (cancelable, keeps the menu open, M:405-416), `checked-change` (`{ checked }`, M:519, fires even if `select` was prevented), `value-change` (`{ value }`, M:555), `escape-key-down`, `pointer-down-outside`, `focus-outside`, `interact-outside` (cancelable, DL:54-99), `open-auto-focus` (cancelable, M:293-296), `close-auto-focus` (cancelable; the caller's handler runs first, CM:137-143). Content lives in `body`, so callers use `@document` actions or listen on the item.

## Structure

### Elements per part (post-connect DOM)

| Part | Tag | `data-slot` | Attributes (source) |
|---|---|---|---|
| ContextMenu | none | (`context-menu` never reaches the DOM) | - |
| Portal | none | (`context-menu-portal` never reaches the DOM) | - |
| Sub | none | (`context-menu-sub` never reaches the DOM) | - |
| Trigger | `span` (or the `as_child` element) | `context-menu-trigger` | `data-state="open\|closed"`, `data-disabled=""` when disabled (CM:87-88), `style="-webkit-touch-callout: none"` + caller style (CM:91). NO `id`, NO `aria-haspopup`, NO `aria-expanded`, NO `aria-controls`, NO `type`, not focusable (CM:84-111). No classes in the oracle; the caller's `class` verbatim. Caller attrs are spread after `data-state`/`data-disabled` (CM:89). `disabled` is NOT rendered as an attribute (it is destructured, CM:58). |
| (anchor) | none | - | `MenuPrimitive.Anchor` with a `virtualRef` (CM:83): no element; a zero-size rect at the last open point. |
| Content | `div` inside `div[data-radix-popper-content-wrapper]` | `context-menu-content` | `role="menu"`, `aria-orientation="vertical"`, `data-state`, `data-radix-menu-content=""`, `dir`, `data-side`, `data-align`, `tabindex="0"`, `data-orientation="vertical"`, `style`: `outline: none`, `pointer-events: auto` while modal, `animation: none` until positioned, plus `--radix-context-menu-content-transform-origin/available-width/available-height` and `--radix-context-menu-trigger-width/height` set to the matching `var(--radix-popper-...)` (CM:148-157). NO `id` and NO `aria-labelledby` (unlike DropdownMenu, CM:128-159 adds none; menu Content has none, M:322-333). Classes: tsx:104 verbatim. |
| Group | `div` | `context-menu-group` | `role="group"`. |
| Label | `div` | `context-menu-label` | `data-inset` rule. Classes tsx:198. |
| Item | `div` | `context-menu-item` | `role="menuitem"`, `data-inset` rule, `data-variant` (always), `tabindex="-1"` (`"0"` for the roving tab stop), `data-orientation="vertical"`, `data-highlighted=""` while focused, `aria-disabled="true"` + `data-disabled=""` when disabled (M:473-476). Classes tsx:128. |
| CheckboxItem | `div` | `context-menu-checkbox-item` | `role="menuitemcheckbox"`, `aria-checked="true\|false\|mixed"`, `data-state="checked\|unchecked\|indeterminate"` (M:512-516), item attributes. Children: `span.pointer-events-none absolute left-2 flex size-3.5 items-center justify-center` (always, tsx:152) holding, only when checked or indeterminate (M:575), `span[data-state]` with `Icon("check", class: "size-4")` (tsx:154), then the block. Classes tsx:146. |
| RadioGroup | `div` | `context-menu-radio-group` | `role="group"`. |
| RadioItem | `div` | `context-menu-radio-item` | `role="menuitemradio"`, `aria-checked="true\|false"`, `data-state="checked\|unchecked"` (M:548-552), item attributes. Indicator span as above with `Icon("circle", class: "size-2 fill-current")` only when checked (tsx:178; indicator span tsx:176). Classes tsx:171. |
| Separator | `div` | `context-menu-separator` | `role="separator"`, `aria-orientation="horizontal"`. Classes tsx:214. Not a roving item. |
| Shortcut | `span` | `context-menu-shortcut` | Classes tsx:227. Part of the item's typeahead text. |
| SubTrigger | `div` | `context-menu-sub-trigger` | `role="menuitem"`, `id`, `aria-haspopup="menu"`, `aria-expanded`, `aria-controls=<sub content id>` ONLY while open (M:670-674), `data-state="open\|closed"`, `data-inset` rule, item attributes. Children: block then `Icon("chevron-right", class: "ml-auto")` (tsx:74; its 16px size comes from the parent's `[&_svg:not([class*='size-'])]:size-4` rule, no `size-4` token on the icon). Classes tsx:68. |
| SubContent | `div` in its own popper wrapper | `context-menu-sub-content` | Same set as Content, plus `id` = sub content id and `aria-labelledby` = SubTrigger id (M:763-764) and the same 5 re-namespaced vars (CM:246-256). Classes tsx:87 verbatim. |

### DOM order, server vs Stimulus

Same mechanism as dropdown-menu: closed Content (and an un-portaled SubContent) is server-rendered inside an inert `<template>` right after its Trigger / SubTrigger; on open the controller clones it into a `div[data-radix-popper-content-wrapper]` (position fixed, transform, `min-width: max-content`, z-index copied from content) appended to the container (default `document.body`); focus guards `span[data-radix-focus-guard]` are the first and last children of `body` while any menu content is mounted. A server-rendered open menu (`open: true`, `force_mount: true`) is rendered inline and moved in `connect()`. `[data-slot]` order the runner sees: Trigger, then Content and its descendants in source order (an un-portaled SubContent sits inside the Content right after its SubTrigger; a portaled one comes after the Content).

Server: all static attributes (role, aria-orientation, data-slot, data-variant, data-inset, data-orientation, data-state, data-disabled, aria-disabled, aria-checked, aria-haspopup/aria-expanded on SubTrigger, tabindex -1, the trigger style). Ids: only each Sub computes `sub_trigger_id` / `sub_content_id` from a per-render counter (no `SecureRandom`). Stimulus: open/close, open point, wrapper + positioning (`data-side`, `data-align`, CSS vars), highlight, roving tabindex, focus, typeahead, dismissal, hide-others, body pointer-events, scroll lock, focus guards, presence, SubTrigger `aria-controls`.

## Behavior

Composes primitives: `portal`, `presence`, `positioner` (with a virtual point reference), `dismissable_layer`, `focus_scope`, `focus_guards`, `scroll_lock`, `hide_others`, `roving_focus`, `typeahead`, `submenu_grace`, `collection`, `ids`, `direction`. One controller `chadcn--context-menu` on the Trigger handles the root and its subs; menu-content logic must be the same shared code as `chadcn--dropdown-menu` (one menu module, two triggers).

### States

- Root `open` closed/open, controllable as in dropdown-menu (CM:35-40); controlled `open: true` keeps the content open on Escape, select and outside click and only dispatches `open-change`. Root has no default-open.
- Open point: `{ x: clientX, y: clientY }` of the opening event (CM:75-79), initially `{ 0, 0 }`; the anchor is `DOMRect.fromRect({ width: 0, height: 0, x, y })` (CM:65).
- Sub open closed/open with `default_open` (CM:224-229); every sub closes when the root closes (M:618-621).
- Trigger `data-state` mirrors root open (CM:87). Content/SubContent `data-state` flips immediately; unmount waits for Presence.
- Checkbox/radio state is controlled only; `force_mount` on Content behaves as in dropdown-menu (M:144-155: hide-others, scroll lock and focus guards apply while mounted-closed; no pointer-events lock, no trap).

### Opening (Trigger, CM:92-109; all handlers do nothing when `disabled`, the caller's handler runs first)

| Input | Effect |
|---|---|
| `contextmenu` event (right mouse button; Chromium fires it on `mousedown` on macOS/Linux) | clear long-press, store the point, set open `true` (an already-open menu just moves to the new point), `preventDefault()` (no native menu) |
| touch/pen `pointerdown` | clear long-press; if open, close; start a 700 ms timer (`long-press-delay` value, Radix constant CM:104) that opens at that point |
| touch/pen `pointermove`, `pointercancel`, `pointerup` | clear the long-press timer (CM:107-109) |
| mouse left click, any key | nothing: the Trigger has no click or key handler. There is no keyboard way to open (the browser's own `contextmenu` from the Menu key / Shift+F10 goes through the same `contextmenu` handler) |
| disconnect / `disabled` becomes true | clear the long-press timer (CM:80-81) |

Keyboard modality: as dropdown-menu (M:67-80): a capture `keydown` sets "using keyboard", the next `pointerdown`/`pointermove` clears it. A right-click open is a pointer open: Content is focused, no item highlighted; ArrowDown/Home/PageUp on the content focus the first enabled item, ArrowUp/End/PageDown the last (M:343-350).

### Keyboard inside the menu

Identical to dropdown-menu (M:334-351, M:432-444, M:740-744, M:780-792; roving focus vertical, `loop` default false, Tab prevented, Enter/Space select, typeahead with 1000 ms reset, sub open on Enter/Space/ArrowRight (ltr) / ArrowLeft (rtl), sub close on ArrowLeft (ltr) / ArrowRight (rtl), Escape in a sub closes the whole menu). Escape on the root closes it (DL:91-107).

### Focus

- Open: Content focused with `preventScroll` (M:293-296) unless `open-auto-focus` is prevented; SubContent focused only when the keyboard is in use (M:772-775).
- Close: there is no trigger to return to. FocusScope restores focus to the element that was focused when the Content mounted, or `body` (FS:92-112). A right-click on a non-focusable span leaves `body` focused, so focus goes to `body`; with `as_child` on a focusable element (a button focused by the right mousedown) focus returns to it. In non-modal mode, after an outside interaction the restore is skipped (`hasInteractedOutsideRef`, CM:137-147). SubContent never restores (M:776). `close-auto-focus` prevented -> no restore.
- Modal: focus trapped (`trapped: open`, M:153), focus-outside never dismisses (M:156-160). Non-modal: not trapped; focus outside dismisses.

### Dismissal, modality, scroll lock, presence

- Same dismissable-layer rules as dropdown-menu: outside listener attached after `setTimeout(0)` (so the opening press is not outside), dismissal on `pointerdown` of ANY button (no button check for menus, DL:265-267), Escape via the topmost layer, portaled SubContent is a child layer.
- Modal (default): body `pointer-events: none`, Content `pointer-events: auto`, `aria-hidden` on everything outside the content wrapper, `react-remove-scroll` scroll lock, focus guards (M:138-165). Consequence: a second right-click anywhere while open (including over the trigger) hits `html`, is an outside pointerdown, closes the menu and does NOT reopen it (the `contextmenu` event targets `html`, not the trigger).
- Non-modal (`modal: false`): no pointer lock, no aria-hidden, no scroll lock, no trap (M:166-179). A right-click elsewhere on the trigger first dismisses (outside pointerdown) and then the trigger's `contextmenu` reopens at the new point; focus is not restored in between.
- `window` `blur` closes an open menu (M:81-88).
- Presence: `data-state="closed"` kept until `animationend`; same frame without motion.

### Positioning

`positioner` with a virtual reference (the zero-size point rect; `autoUpdate` without element listeners on the reference). Content: side `right`, side offset `2`, align `start` always (CM:134-136), so by default the content's top-left is at (x + 2, y), `data-side="right"`, `data-align="start"`. Same middleware order and options as dropdown-menu: `offset({ mainAxis: 2, alignmentAxis: align_offset })`, `shift` (main axis = vertical for side right; `limitShift` when `sticky: "partial"`), `flip` (to `left` near the right edge), `size` (writes the available width/height vars; content `max-h-(--radix-context-menu-content-available-height)` + `overflow-y-auto` scroll long menus), `transformOrigin` (`--radix-popper-transform-origin`), `hide` when `hide_when_detached`. In rtl the root Content side stays `right` (forced, CM:134) while SubContent uses `left` (M:768). SubContent anchors on its SubTrigger exactly as in dropdown-menu.

### Timers (Stimulus values, Radix defaults)

`long-press-delay` 700 ms (CM:104), `sub-open-delay` 100 ms (M:693), `pointer-grace-timeout` 300 ms (M:723), `typeahead-timeout` 1000 ms (M:244), outside-listener attach delay 0 ms.

### Scenario notes

Opening requires a right click: scenario steps use `{"do": "click", "button": "right"}` and `{"do": "mousedown"/"mouseup", "button": "right"}` (press-drag-release, M:425-431: pointerup on an item that did not get the pointerdown clicks it). Static visual cells use controlled `open: true` (content anchored at (2, 0)) so they do not depend on the opening path. Collision scenarios use a `fixed inset-0` trigger so `position` equals viewport coordinates. Outside clicks target `html` at `{x: 860, y: 20}` (body has `pointer-events: none` in modal mode). The demo renders `SubContent` un-portaled, so sub scenarios default to inline and `sub__portal*` cover the portaled path. Touch/pen long-press has no runner step and is not covered by a scenario; `test/javascript/context_menu.test.mjs` covers it (700 ms hold opens at the press point, `pointerup`/`pointermove`/`pointercancel` cancel, mouse ignored, disabled, disconnect), run with `bin/rails test:javascript`.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::ContextMenu` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render ContextMenu::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::ContextMenu::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `context_menu.trigger` | `ContextMenu::Trigger` | `ContextMenuTrigger` |
| `context_menu.content` | `ContextMenu::Content` | `ContextMenuContent` |
| `context_menu.item` | `ContextMenu::Item` | `ContextMenuItem` |
| `context_menu.checkbox_item` | `ContextMenu::CheckboxItem` | `ContextMenuCheckboxItem` |
| `context_menu.radio_item` | `ContextMenu::RadioItem` | `ContextMenuRadioItem` |
| `context_menu.label` | `ContextMenu::Label` | `ContextMenuLabel` |
| `context_menu.separator` | `ContextMenu::Separator` | `ContextMenuSeparator` |
| `context_menu.shortcut` | `ContextMenu::Shortcut` | `ContextMenuShortcut` |
| `context_menu.group` | `ContextMenu::Group` | `ContextMenuGroup` |
| `context_menu.portal` | `ContextMenu::Portal` | `ContextMenuPortal` |
| `context_menu.sub` | `ContextMenu::Sub` | `ContextMenuSub` |
| `context_menu.sub_content` | `ContextMenu::SubContent` | `ContextMenuSubContent` |
| `context_menu.sub_trigger` | `ContextMenu::SubTrigger` | `ContextMenuSubTrigger` |
| `context_menu.radio_group` | `ContextMenu::RadioGroup` | `ContextMenuRadioGroup` |

Names that shadow a Phlex HTML element inside `ContextMenu`'s OWN `view_template` (use `tag(:label)` there, never the bare method): `label`, `sub`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Chadcn::Icon` (`check` in CheckboxItem, `circle` in RadioItem, `chevron-right` in SubTrigger; lucide 0.577.0, classes tsx:74, 154, 178).
- `Chadcn::Base` (`render_as_child`, `merge_attrs`, `cn`).
- Shared menu module with `chadcn--dropdown-menu` (content, items, subs, typeahead), via the primitives above. No other Chadcn component is rendered.

## Deviations

None. The closed-state `<template>` is invisible to the DOM tree, layout and accessibility (same mechanism as dropdown-menu), and `container:` as a selector is the api-mapping translation of a DOM reference, so no `deviations/context-menu.json` is written.
