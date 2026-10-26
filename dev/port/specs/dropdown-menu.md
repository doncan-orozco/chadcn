# dropdown-menu

Oracle: `dev/port/oracle/src/dropdown-menu.tsx` (new-york-v4, `radix-ui` 1.7.0) + `oracle/manifest/dropdown-menu.json` (tier `overlay`, no cva, no registry dependencies).
Radix sources read (catalog `dev/react-shadcn-catalog/node_modules/@radix-ui/`): `react-dropdown-menu` 2.1.25 (cited `DM:<line>`), `react-menu` 2.1.25 (`M:`), `react-popper` 1.3.8 (`P:`), `react-roving-focus` 1.1.20 (`RF:`), `react-dismissable-layer` 1.1.20 (`DL:`), `react-focus-guards` 1.1.6 (`FG:`), `react-focus-scope` 1.2.0 (`FS:`), `react-presence` 1.1.11, `react-portal` 1.1.18; `react-remove-scroll` 2.7.2 / `react-remove-scroll-bar` 2.3.8, `aria-hidden` 1.2.6, `@floating-ui/dom` 1.8.0 (via `@floating-ui/react-dom`), `lucide-react` 0.577.0. Line numbers are of each package's `dist/index.mjs`.

## API

Namespace `Chadcn::DropdownMenu`. Every option accepts strings and symbols (`side: :top` == `side: "top"`, `variant: :destructive` == `"destructive"`). `class:` is merged last through `cn` (caller wins); `data:`/`aria:` hashes deep-merge with the part's required attributes; every other key in `**attrs` passes through to the part's element (`id`, `role`, `aria-*`, `data-*`, `style`, `title`...). `as_child:` is `false | tag symbol | Chadcn component instance` and uses `Chadcn::Base#render_as_child` (Radix Slot merge, api-mapping.md) on every part that is a Radix `Primitive` (all parts below except `DropdownMenu`, `Portal`, `Sub`, `Shortcut`, which is a plain `span` in the oracle and has no `asChild`).

| React export | Ruby call (kwargs with defaults) | Notes / source |
|---|---|---|
| `DropdownMenu` | `Chadcn::DropdownMenu.new(open: nil, default_open: false, modal: true, dir: nil) { ... }` | Renders NO element (manifest `non_rendered_slots`; DM:41-54). `open:` non-nil = controlled (server renders that state; user actions only dispatch `open-change`, DM:35-40 `useControllableState`). `default_open:` initial uncontrolled state. `modal:` default `true` (DM:31). `dir:` `"ltr" \| "rtl"`; when nil the direction is `"ltr"` (`useDirection(dir)` reads the prop or a DirectionProvider, never `html[dir]`). Unknown kwargs raise `ArgumentError` (Radix Root takes no DOM props). |
| `DropdownMenuTrigger` | `DropdownMenu::Trigger.new(as_child: false, disabled: false, **attrs) { ... }` | `<button type="button">` (DM:65-75). Hosts the `chadcn--dropdown-menu` controller. Caller `id:` wins over the generated id (DM:75 spreads `triggerProps` after `id`), but Content keeps `aria-labelledby` pointing to the generated trigger id, exactly as Radix (relation then resolves to nothing). |
| `DropdownMenuPortal` | `DropdownMenu::Portal.new(force_mount: false, container: nil) { ... }` | Renders NO element (M:122-126). `container:` is a CSS selector string (React takes a DOM node; a node reference has no Ruby form, see api-mapping `ref` row); default `document.body`. Only meaningful around `SubContent` (shadcn's `Content` already wraps itself in a Portal, tsx:39). |
| `DropdownMenuContent` | `DropdownMenu::Content.new(side: "bottom", side_offset: 4, align: "center", align_offset: 0, avoid_collisions: true, collision_padding: 0, collision_boundary: nil, sticky: "partial", hide_when_detached: false, update_position_strategy: "optimized", arrow_padding: 0, loop: false, force_mount: false, as_child: false, class: nil, **attrs) { ... }` | `side_offset` default is shadcn's `4` (tsx:35), all others are Radix defaults (P:96-110, M:186). `side`: `top right bottom left`; `align`: `start center end`; `sticky`: `partial always`; `update_position_strategy`: `optimized always`; `collision_padding`: Integer or Hash `{ top:, right:, bottom:, left: }` (missing keys 0, P:116); `collision_boundary`: CSS selector or array of selectors. Always portaled (tsx:39). `force_mount:` is accepted for API parity but has NO effect: shadcn wraps Content in a `DropdownMenuPrimitive.Portal` that is not force-mounted (tsx:38-39), and that Portal's own Presence (`present: forceMount \|\| context.open`, M:123-125) unmounts everything while closed; the oracle scenario `content__force-mount-closed` renders nothing. |
| `DropdownMenuGroup` | `DropdownMenu::Group.new(as_child: false, class: nil, **attrs) { ... }` | `div role="group"` (M:382-387). No classes in the oracle. |
| `DropdownMenuLabel` | `DropdownMenu::Label.new(inset: nil, as_child: false, class: nil, **attrs) { ... }` | `div` (M:388-393). `inset:` nil -> no `data-inset`; `true` -> `data-inset="true"`; `false` -> `data-inset="false"` (tsx:155 `data-inset={inset}`). |
| `DropdownMenuItem` | `DropdownMenu::Item.new(variant: "default", inset: nil, disabled: false, text_value: nil, as_child: false, class: nil, **attrs) { ... }` | `variant:` `"default" \| "destructive"`, rendered verbatim as `data-variant` (tsx:64,74; React does not validate it either). `text_value:` overrides the typeahead text (M:451,469). Selecting dispatches cancelable `select`. |
| `DropdownMenuCheckboxItem` | `DropdownMenu::CheckboxItem.new(checked: false, disabled: false, text_value: nil, as_child: false, class: nil, **attrs) { ... }` | `checked:` `true \| false \| "indeterminate"` (M:508). Controlled only, like Radix (no `defaultChecked` exists): the port never flips it on its own; it dispatches `checked-change` and the caller re-renders / updates. |
| `DropdownMenuRadioGroup` | `DropdownMenu::RadioGroup.new(value: nil, as_child: false, class: nil, **attrs) { ... }` | `div role="group"` (M:532-538). Controlled only (no `defaultValue` in Radix). |
| `DropdownMenuRadioItem` | `DropdownMenu::RadioItem.new(value:, disabled: false, text_value: nil, as_child: false, class: nil, **attrs) { ... }` | `value:` required String (M:542). Checked iff `value == RadioGroup value` (M:544). |
| `DropdownMenuSeparator` | `DropdownMenu::Separator.new(as_child: false, class: nil, **attrs)` | `div role="separator" aria-orientation="horizontal"` (M:588-601). |
| `DropdownMenuShortcut` | `DropdownMenu::Shortcut.new(class: nil, **attrs) { ... }` | Plain `span` (tsx:178-192). |
| `DropdownMenuSub` | `DropdownMenu::Sub.new(open: nil, default_open: false) { ... }` | Renders NO element (DM:197-207, M:611-643). Same controlled/uncontrolled rule as the root. Unknown kwargs raise `ArgumentError`. |
| `DropdownMenuSubTrigger` | `DropdownMenu::SubTrigger.new(inset: nil, disabled: false, text_value: nil, as_child: false, class: nil, **attrs) { ... }` | Block content is followed by the chevron icon (tsx:218-219). Caller `id:` wins over the generated one (M:675). |
| `DropdownMenuSubContent` | `DropdownMenu::SubContent.new(side_offset: 0, align: "start", align_offset: 0, avoid_collisions: true, collision_padding: 0, collision_boundary: nil, sticky: "partial", hide_when_detached: false, update_position_strategy: "optimized", arrow_padding: 0, loop: false, force_mount: false, as_child: false, class: nil, **attrs) { ... }` | `side` is NOT an option: forced to `"right"` (ltr) / `"left"` (rtl) (M:768). `align` default `"start"` (M:754). shadcn passes no `sideOffset` -> Radix 0. Portaled only when wrapped in `DropdownMenu::Portal`; otherwise rendered in place inside the parent Content (combobox example). `force_mount:` (or the wrapping `DropdownMenu::Portal`'s `force_mount:`, inherited via `portalContext.forceMount`, M:754) keeps the SubContent mounted while the sub is closed (M:760), as long as the parent Content is mounted. |

Not exported by shadcn, so not part of the API: `DropdownMenuArrow`, `DropdownMenuItemIndicator` (used internally by CheckboxItem/RadioItem), `asChild` on the root.

### Events (`this.dispatch`, prefix `chadcn--dropdown-menu`, all `bubbles: true`)

| Event | Dispatched on | `detail` | Cancelable | Radix equivalent |
|---|---|---|---|---|
| `open-change` | Trigger (root) / SubTrigger (sub) | `{ open }` | no | `onOpenChange` (DM:38, DM:203) |
| `select` | the item element | `{}` | yes: `preventDefault()` keeps the menu open (M:405-416) | `onSelect` on Item/CheckboxItem/RadioItem |
| `checked-change` | CheckboxItem | `{ checked }` (next = `indeterminate ? true : !checked`, M:519) | no; fires even when `select` was prevented (`checkForDefaultPrevented: false`, M:520) | `onCheckedChange` |
| `value-change` | RadioItem (bubbles through RadioGroup) | `{ value }` (M:555) | no; fires even when `select` was prevented | `onValueChange` |
| `escape-key-down` | Content / SubContent | `{ originalEvent }` | yes: prevents dismissal (DL:91-99) | `onEscapeKeyDown` |
| `pointer-down-outside` | Content / SubContent | `{ originalEvent }` | yes | `onPointerDownOutside` |
| `focus-outside` | Content / SubContent | `{ originalEvent }` | yes (modal Content always prevents it itself, M:156-160) | `onFocusOutside` |
| `interact-outside` | Content / SubContent | `{ originalEvent }` | yes | `onInteractOutside` |
| `open-auto-focus` | Content | `{}` | yes: content is not focused (M:293-296) | `onOpenAutoFocus` |
| `close-auto-focus` | Content | `{}` | yes: focus is not returned to the trigger (DM:114-118 composes the caller first) | `onCloseAutoFocus` |

Content in the body is outside any caller controller element, so callers listen with a global action (`data-action="chadcn--dropdown-menu:select@document->foo#bar"`) or on the item element itself. `onClick`, `onPointerMove`... are plain DOM events (`data: { action: }`), composed before the port's own handlers as Radix `composeEventHandlers` does (caller first; `event.preventDefault()` in a caller `click` on an Item suppresses selection, M:424).

## Structure

### Elements per part (post-connect DOM; attribute order irrelevant)

| Part | Tag | `data-slot` | Attributes (source) |
|---|---|---|---|
| DropdownMenu | none | (`dropdown-menu` never reaches the DOM) | - |
| Portal | none | (`dropdown-menu-portal` never reaches the DOM) | - |
| Sub | none | (`dropdown-menu-sub` never reaches the DOM) | - |
| Trigger | `button` (or the `as_child` element) | `dropdown-menu-trigger` | `type="button"`, `id`, `aria-haspopup="menu"`, `aria-expanded="true\|false"`, `aria-controls=<content id>` ONLY while open, `data-state="open\|closed"`, `data-disabled=""` + `disabled=""` when disabled (DM:65-75); `data-radix-popper-side/align` while placed (P:84-92, ignored by the runner). No classes (tsx:22-31). |
| Content | `div` inside `div[data-radix-popper-content-wrapper]` | `dropdown-menu-content` | `role="menu"`, `aria-orientation="vertical"`, `data-state`, `data-radix-menu-content=""`, `dir="ltr\|rtl"` (M:325-329), `id`, `aria-labelledby=<trigger id>` (DM:109-110), `data-side`, `data-align` (P:225-226), `tabindex="-1"` ALWAYS (FocusScope renders `Primitive.div` with `tabIndex: -1` (FS:145) and forwards it via `asChild` through DismissableLayer to the RovingFocusGroup, whose `...groupProps` spread comes after its own computed `tabIndex` (RF:100-102), so the group's 0/-1 is overridden; verified on the oracle), `data-orientation="vertical"` (RF:101), `style`: `outline: none` (M:333), `pointer-events: auto` while a modal layer disables the body (DL:147), `animation: none` until positioned (P:233), plus the 5 re-namespaced vars `--radix-dropdown-menu-content-transform-origin/available-width/available-height/trigger-width/trigger-height: var(--radix-popper-...)` (DM:125-135). Classes: tsx:44 verbatim. |
| Group | `div` | `dropdown-menu-group` | `role="group"`. |
| Label | `div` | `dropdown-menu-label` | `data-inset` per the inset rule. Classes tsx:157. |
| Item | `div` (or `as_child` element) | `dropdown-menu-item` | `role="menuitem"`, `data-inset` (rule), `data-variant` (always, default `"default"`), `tabindex="-1"` (`"0"` when it is the roving tab stop, RF:188), `data-orientation="vertical"` (RF:189), `data-highlighted=""` while focused, `aria-disabled="true"` + `data-disabled=""` when disabled (M:473-476). Classes tsx:76. |
| CheckboxItem | `div` | `dropdown-menu-checkbox-item` | `role="menuitemcheckbox"`, `aria-checked="true\|false\|mixed"`, `data-state="checked\|unchecked\|indeterminate"` (M:512-516), plus the Item attributes (tabindex, data-orientation, data-highlighted, aria-disabled/data-disabled). No `data-variant`/`data-inset`. Classes tsx:94. Children: `span.pointer-events-none absolute left-2 flex size-3.5 items-center justify-center` (always rendered, tsx:100) containing, ONLY when checked or indeterminate (Presence, M:575), `span[data-state]` with `Icon("check", class: "size-4")` (the check icon is shown for indeterminate too), then the block content. |
| RadioGroup | `div` | `dropdown-menu-radio-group` | `role="group"`. |
| RadioItem | `div` | `dropdown-menu-radio-item` | `role="menuitemradio"`, `aria-checked="true\|false"`, `data-state="checked\|unchecked"` (M:548-552), Item attributes. Classes tsx:130. Indicator span as above, inner `span[data-state="checked"]` with `Icon("circle", class: "size-2 fill-current")` only when checked. |
| Separator | `div` | `dropdown-menu-separator` | `role="separator"`, `aria-orientation="horizontal"`. Classes tsx:172. Not focusable, not a roving item. |
| Shortcut | `span` | `dropdown-menu-shortcut` | Classes tsx:186. Its text is part of the item's typeahead text (textContent, M:461). |
| SubTrigger | `div` | `dropdown-menu-sub-trigger` | `role="menuitem"`, `id`, `aria-haspopup="menu"`, `aria-expanded="true\|false"`, `aria-controls=<sub content id>` ONLY while open, `data-state="open\|closed"` (M:670-674), `data-inset` (rule), Item attributes (tabindex, data-orientation, data-highlighted, aria-disabled/data-disabled). Children: block then `Icon("chevron-right", class: "ml-auto size-4")` (tsx:219; not mirrored in rtl). Classes tsx:213. |
| SubContent | `div` inside its own popper wrapper | `dropdown-menu-sub-content` | Same set as Content (role, aria-orientation, data-state, data-radix-menu-content, dir, data-side, data-align, `tabindex="-1"` always (same FocusScope override), data-orientation, outline, pointer-events, vars) with `id` = sub content id and `aria-labelledby` = SubTrigger id (M:763-764). Classes tsx:232 verbatim. |

Note: `radix-dom-contract.md` "Verified corrections" says SubTrigger always carries `aria-controls`; the installed source (M:673) only sets it while open. The source wins.

### DOM order and what the server renders

Closed (initial, uncontrolled): the server renders the Trigger in place and the Content markup inside an inert `<template>` immediately after it (same for an un-portaled SubContent: a `<template>` in place after its SubTrigger; a portaled SubContent: a `<template>` in place). The template carries no `data-slot`, no classes, no text in the live DOM (its content is a DocumentFragment, invisible to `querySelectorAll`, layout and the a11y tree), so the post-connect DOM equals Radix's "nothing mounted while closed" (Presence, M:125, M:135). It is the mechanism, not a deviation. Only the controller wiring (`data-chadcn--dropdown-menu-*-value`, an id for lookup) may sit on it.

Open (on open, or initial when `open:`/`default_open:` is true; for a SubContent also `force_mount:` while its parent Content is mounted): the controller clones the Content into `<div data-radix-popper-content-wrapper dir=... style="position: fixed; left: 0; top: 0; transform: translate(x, y); min-width: max-content; z-index: <computed z-index of content, 50>; --radix-popper-transform-origin: ...">` (P:210-232) and appends the wrapper to the container (default `document.body`, end of body; M:125 Portal). A server-rendered open menu is rendered inline and moved there in `connect()`. Focus guards: while any menu content is mounted, `span[data-radix-focus-guard]` (tabindex 0, opacity 0, position fixed, pointer-events none, FG:39-47) is the first and the last child of `body`, ref-counted (FG:14-36). A portaled SubContent is appended to the container as another wrapper; an un-portaled SubContent's wrapper sits inside the parent Content right after its SubTrigger.

Resulting `[data-slot]` order the runner sees (open, portaled sub open): Trigger, (anything after it in the page), Content, Content's descendants in source order (SubTrigger included), then SubContent and its descendants.

### Server vs Stimulus

Server: every static attribute above (role, aria-haspopup, aria-orientation, data-slot, data-variant, data-inset, data-orientation, initial data-state, aria-expanded, aria-checked, data-disabled/aria-disabled, tabindex -1 on items, ids). Ids: the root computes `trigger_id` and `content_id`, each Sub computes `sub_trigger_id` and `sub_content_id`, from a per-render counter (no `SecureRandom`); relations matter, not values (runner normalizes). Stimulus: open/close, `aria-controls` toggling, popper wrapper + positioning (`data-side`, `data-align`, CSS vars), `data-highlighted`, roving `tabindex` on items (Content/SubContent stay `-1`, server-rendered), focus, typeahead, dismissal, `aria-hidden` on others, body `pointer-events`, scroll lock, focus guards, presence.

## Behavior

Composes primitives: `portal`, `presence`, `positioner`, `dismissable_layer`, `focus_scope`, `focus_guards`, `scroll_lock`, `hide_others`, `roving_focus`, `typeahead`, `submenu_grace`, `collection`, `ids`, `direction`. One controller `chadcn--dropdown-menu` on the Trigger handles the root and its subs.

### States

- Root `open` closed/open. Uncontrolled: user actions set it and dispatch `open-change`. Controlled (`open:` given): user actions only dispatch `open-change`; DOM stays (e.g. Escape on `open: true` keeps it open, DM:35-40).
- Sub `open` closed/open, same controllable rule (DM:200-205). Whenever the root closes, every sub is set closed (`if (parentMenuContext.open === false) handleOpenChange(false)`, M:618-621), including a `default_open: true` sub. Further, an UNCONTROLLED `default_open: true` sub is CLOSED after the menu mounts: the MenuSub effect's cleanup also calls `handleOpenChange(false)` (`return () => handleOpenChange(false)`, M:618-621), which fires during the mount cycle and closes the uncontrolled state (verified in the oracle: all 6 scenarios with `defaultOpen` on a Sub render a closed SubTrigger, `data-state="closed"`, `aria-expanded="false"`, no SubContent). So the port renders a `default_open: true` sub exactly like a closed one. A CONTROLLED `open: true` sub stays open (the cleanup only dispatches `open-change` with `false`; the DOM follows the prop).
- Trigger `data-state`/`aria-expanded` and SubTrigger `data-state`/`aria-expanded` flip immediately; Content/SubContent `data-state` flips immediately and the element stays mounted until its exit animation ends (Presence).
- Item highlight = DOM focus (`data-highlighted` on focus, removed on blur, M:474, M:497-498).
- CheckboxItem/RadioItem checked state is controlled only (never changed by the port).
- `force_mount: true` on the root Content has no effect (see API: the non-force-mounted shadcn Portal unmounts it while closed; scenario `content__force-mount-closed` shows nothing mounted). `force_mount: true` on a SubContent (or its `DropdownMenu::Portal`) keeps it mounted while the sub is closed with `data-state="closed"` (M:754-760), only while the root is open. Radix internals for a force-mounted root content (not reachable through shadcn, kept for reference): in modal mode the mounted-but-closed content would apply `hideOthers` (M:144-147 runs on mount, not on open), scroll lock (`disableOutsideScroll: true` unconditionally, M:155) and focus guards, but not body `pointer-events: none` (`disableOutsidePointerEvents: context.open`, M:154) and no focus trap (`trapFocus: context.open`, M:153); the focus scope's mount autofocus would focus the content (M:293-296).

### Keyboard

Trigger (DM:83-88, ignored when disabled):

| Key | Effect |
|---|---|
| `Enter`, `Space` | toggle open; `preventDefault` |
| `ArrowDown` | open (never closes); `preventDefault` |
| others (incl. `ArrowUp`) | nothing |

Keyboard modality: a capture `keydown` on `document` sets "using keyboard"; the next `pointerdown` or `pointermove` (capture, once) clears it (M:67-80). Only with "using keyboard" does focus entering the Content move on to the first item (entry focus, M:318-320, RF:117-131).

Inside Content / SubContent (M:334-351, RF:197-217, M:432-444):

| Key | Where | Effect |
|---|---|---|
| `ArrowDown` / `ArrowUp` | on an item | next / previous enabled item; no wrap unless `loop: true` (M:186, RF:211); disabled items skipped (`focusable: !disabled`, M:470) |
| `Home`, `PageUp` / `End`, `PageDown` | on an item | first / last enabled item |
| `ArrowDown`, `PageUp`, `Home` | on the content element itself (no item focused) | first enabled item (M:38, M:345-350) |
| `ArrowUp`, `PageDown`, `End` | on the content element itself | last enabled item |
| `ArrowLeft`/`ArrowRight` | on a plain item | nothing (vertical orientation, RF:236-238) |
| any arrow/Home/End with Meta/Ctrl/Alt/Shift | on an item | ignored (RF:206) |
| `Enter`, `Space` | on an item | `click()` -> select (M:440-443); Space is ignored while a typeahead search is pending (M:436-439) |
| `Enter`, `Space`, `ArrowRight` (ltr) / `ArrowLeft` (rtl) | on a SubTrigger | open the sub and focus its content (M:740-744); entry focus then moves to its first item because the keyboard is in use (M:772-775) |
| `ArrowLeft` (ltr) / `ArrowRight` (rtl) | inside a SubContent | close that sub, focus its SubTrigger (M:784-792) |
| `Tab`, `Shift+Tab` | anywhere inside a menu content | `preventDefault` (focus never leaves, M:340). `Shift+Tab` on an item still marks the roving group as "tabbing back out" (RF:198-201); the content's `tabindex` is `-1` regardless (FocusScope override, see Structure) |
| printable character (no Ctrl/Alt/Meta) | anywhere inside a menu content | typeahead (below) |
| `Escape` | anywhere (document capture listener of the topmost layer, DL:90-107) | root: close, focus trigger. In a sub: closes the WHOLE menu (`rootContext.onClose()`, M:780-783) and focus returns to the trigger |

Typeahead (M:233-249, M:822-833): buffer = previous buffer + key, reset 1000 ms after the last key (`typeahead_timeout` value, default 1000) and on blur leaving the content (M:352-357). Candidates = enabled items of THAT content only (sub contents have their own collection), in DOM order, text = `text_value` or trimmed `textContent` (shortcut text included). If the buffer is one repeated char, search for that char cycling from the current item excluding it; single-char searches exclude the current item; match is case-insensitive `startsWith`; focus moves in a `setTimeout` (M:246-248). Space is a character and joins the buffer.

### Focus

- Open: Content is focused (`preventScroll`) by the focus-scope mount autofocus (M:293-296) unless `open-auto-focus` is prevented; then entry focus moves to the first enabled item only if the keyboard is in use. Pointer open -> content focused, no item highlighted.
- SubContent open: focused only when the keyboard is in use (M:772-775); pointer-opened subs leave focus on the SubTrigger.
- Pointer over an enabled item (mouse only): focus it (`preventScroll`), it becomes the roving tab stop (`tabindex="0"`). Pointer over a disabled item, or leaving an item: focus returns to the content and the tab stop is cleared (all items `tabindex="-1"`) unless the pointer is moving toward an open sub within the grace area (M:263-276, M:479-496).
- Close: when the Content unmounts (after Presence exit), focus goes to the trigger, unless the close came from an outside interaction in non-modal mode or a right / ctrl-left click outside (`hasInteractedOutside`, DM:114-124), or `close-auto-focus` is prevented. SubContent never restores focus on close (M:776).
- Modal: focus is trapped (`trapped: open`, M:153) and focus-outside never dismisses (M:156-160). Non-modal: not trapped; focus moving outside dismisses.
- Select: after select the menu closes and focus returns to the trigger (modal and non-modal, click or keyboard).

### Pointer

- Trigger `pointerdown` with button 0 and no Ctrl toggles open; when opening it calls `preventDefault` so the trigger does not take focus (DM:77-82). Disabled: nothing.
- Item: `click` selects (M:424); `pointerup` on an item that did not receive the `pointerdown` triggers `click()` (press on the trigger, drag, release on an item selects it, M:425-431).
- SubTrigger: mouse `pointermove` starts a 100 ms timer that opens the sub (`sub_open_delay`, M:688-694); `click` opens it immediately and focuses the SubTrigger (M:677-682); `pointerleave` clears the timer and, if the sub content exists, records a grace polygon from the exit point (x bleed -5 when the sub is on the right, +5 on the left) to the sub content's near/far edges, cleared after 300 ms (`pointer_grace_timeout`, M:697-724). While the pointer moves toward the sub (direction tracked on content `pointermove`, M:358-369) inside that polygon, item enter/leave in the parent are ignored (M:254-282). Pointer handlers only react to `pointerType === "mouse"` (M:857-859).
- Sub closes when focus moves outside it to anything other than its SubTrigger (M:777-779), e.g. hovering another parent item.

### Dismissal, modality, scroll lock, presence

- Dismissable layer per Content and SubContent (layer stack; only the topmost reacts to Escape). The outside `pointerdown` listener is attached in a `setTimeout(0)` after mount so the opening pointerdown is not "outside" (DL:292-294). Outside = not inside the layer or a branch; a portaled SubContent is a child layer, so pressing inside it is not outside the root. Menus do not defer pointer-down-outside (default `deferPointerDownOutside = false`, DL:32): dismissal happens on `pointerdown`.
- Modal (default): body `pointer-events: none` while open (restored to its previous inline value when the last such layer goes, DL:110-126), Content `pointer-events: auto`; `aria-hidden="true"` (+ `data-aria-hidden`) on everything outside the content's wrapper (aria-hidden `hideOthers`, M:144-147), restored on unmount; scroll lock = `react-remove-scroll` (body `data-scroll-locked="1"` counter, `overflow: hidden !important`, `overscroll-behavior: contain`, scrollbar gap compensation as margin-right), shards = content + branch nodes (M:223-232), pinch-zoom allowed. Outside pointerdown (left button) dismisses and focus returns to the trigger.
- Non-modal (`modal: false`): no pointer-events, no aria-hidden, no scroll lock, no trap (M:166-179); outside pointerdown or focus outside dismisses and focus is NOT returned to the trigger; the trigger pointerdown toggles closed.
- `window` `blur` closes an open menu (M:81-88).
- Presence: on close, Content/SubContent keep `data-state="closed"` until `animationend` of the `animate-out` animation, then unmount (and only then release hide-others / scroll lock / focus scope, return focus); with no animation (reduced motion, the runner's no-motion style) they unmount in the same frame. Same on open: `animate-in` runs from `data-state="open"`; the popper sets `animation: none` until it has positioned (P:231-234).

### Positioning (`positioner`, floating-ui, strategy `fixed`)

Middleware in Radix order (P:139-183): `offset({ mainAxis: side_offset + arrowHeight(0), alignmentAxis: align_offset })`, `shift({ mainAxis: true, crossAxis: false, limiter: sticky == "partial" ? limitShift() : none })` (when `avoid_collisions`), `flip()` (when `avoid_collisions`), `size` (writes `--radix-popper-available-width/height` and `--radix-popper-anchor-width/height` on the content), `transformOrigin` (writes `--radix-popper-transform-origin` on the wrapper; no arrow: `0%|50%|100%` by align on the cross axis, `0px` / `<content height>px` / `<content width>px` on the main axis, P:319-351), `hide({ strategy: "referenceHidden" })` only when `hide_when_detached` (wrapper `visibility: hidden; pointer-events: none` when hidden). All share `padding: collision_padding`, `boundary`, `altBoundary: boundary given`. `autoUpdate` (animationFrame when `update_position_strategy: "always"`), released on close. Placement -> `data-side`/`data-align` on the content. Content `max-h-(--radix-dropdown-menu-content-available-height)` + `overflow-y-auto` make long menus scroll inside the viewport. SubContent anchors on its SubTrigger with side `right` (ltr) / `left` (rtl), flipping when it does not fit.

### Timers (Stimulus values, Radix defaults)

`sub-open-delay` 100 ms (M:693), `pointer-grace-timeout` 300 ms (M:723), `typeahead-timeout` 1000 ms (M:244), outside-listener attach delay 0 ms (DL:292).

### Scenario notes

The registry examples use `Button` as the `asChild` trigger, but the manifest lists no registry dependencies, so scenario trees cannot use `Button`; `example__*` trees use a raw `_button` as the `asChild` child (same Slot path, no Button classes). `example__dropdown-menu-dialog` keeps only the menu (Dialog/Field/Input are other components) and `example__combobox-dropdown-menu` replaces the `Command` inside the un-portaled SubContent with plain items. Outside clicks target `html` at `{x: 860, y: 20}` because a modal menu sets `body` `pointer-events: none` (Playwright cannot hit-test anything else). Disabled items are exercised through keyboard and typeahead (they are `pointer-events-none`, so Playwright cannot hover/click them).

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::DropdownMenu` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render DropdownMenu::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::DropdownMenu::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `dropdown_menu.portal` | `DropdownMenu::Portal` | `DropdownMenuPortal` |
| `dropdown_menu.trigger` | `DropdownMenu::Trigger` | `DropdownMenuTrigger` |
| `dropdown_menu.content` | `DropdownMenu::Content` | `DropdownMenuContent` |
| `dropdown_menu.group` | `DropdownMenu::Group` | `DropdownMenuGroup` |
| `dropdown_menu.label` | `DropdownMenu::Label` | `DropdownMenuLabel` |
| `dropdown_menu.item` | `DropdownMenu::Item` | `DropdownMenuItem` |
| `dropdown_menu.checkbox_item` | `DropdownMenu::CheckboxItem` | `DropdownMenuCheckboxItem` |
| `dropdown_menu.radio_group` | `DropdownMenu::RadioGroup` | `DropdownMenuRadioGroup` |
| `dropdown_menu.radio_item` | `DropdownMenu::RadioItem` | `DropdownMenuRadioItem` |
| `dropdown_menu.separator` | `DropdownMenu::Separator` | `DropdownMenuSeparator` |
| `dropdown_menu.shortcut` | `DropdownMenu::Shortcut` | `DropdownMenuShortcut` |
| `dropdown_menu.sub` | `DropdownMenu::Sub` | `DropdownMenuSub` |
| `dropdown_menu.sub_trigger` | `DropdownMenu::SubTrigger` | `DropdownMenuSubTrigger` |
| `dropdown_menu.sub_content` | `DropdownMenu::SubContent` | `DropdownMenuSubContent` |

Names that shadow a Phlex HTML element inside `DropdownMenu`'s OWN `view_template` (use `tag(:label)` there, never the bare method): `label`, `sub`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Chadcn::Icon` (`check` in CheckboxItem, `circle` in RadioItem, `chevron-right` in SubTrigger; lucide 0.577.0 SVGs with the classes from tsx:102, 137, 219).
- `Chadcn::Base` (`render_as_child`, `merge_attrs`, `cn`).
- No other Chadcn component. Callers commonly pass `Chadcn::Button` instances to `Trigger.new(as_child:)`.

## Deviations

None. The closed-state `<template>` is invisible to the DOM tree, layout and accessibility (see Structure) and the `container:` selector is the api-mapping translation of a DOM reference, so no `deviations/dropdown-menu.json` is written.
