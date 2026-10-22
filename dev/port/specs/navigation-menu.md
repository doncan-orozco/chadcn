# NavigationMenu (shadcn new-york-v4, Radix `NavigationMenu`)

Oracle: `gems/chadcn/dev/port/oracle/src/navigation-menu.tsx` (manifest `source_sha` fbe81d7c358df0d2, cited `tsx:<line>`), manifest `oracle/manifest/navigation-menu.json`.
Behavior source: `gems/chadcn/dev/react-shadcn-catalog/node_modules/@radix-ui/react-navigation-menu/dist/index.mjs` v1.3.0 (cited `nm:<line>`), built on `react-dismissable-layer` 1.1.20 (`dl:`), `react-presence` 1.1.11, `react-visually-hidden` 1.2.12 (`vh:`), `react-collection` 1.1.16, `react-id` 1.1.4, `react-slot` 1.4.0 (`slot:`), `react-direction`, `react-use-previous`; all from `radix-ui` 1.7.0, React 19.3.0, tailwind-merge 2.6.1.
Examples: registry `new-york-v4/navigation-menu-demo.json` (fetched); docs example `apps/v4/examples/radix/navigation-menu-rtl.tsx` (shadcn-ui/ui main, radix-nova style; markup re-expressed with the new-york-v4 parts). The registry item has no `meta.links`.
Tier: `overlay`. Family: Menu (no floating-ui: content and viewport are positioned by CSS, `absolute top-full`).

Notes for `radix-dom-contract.md` (checklist row "NavigationMenu"): correct, but incomplete. Read from source: the trigger has NO `aria-haspopup`; `aria-controls` is only present while open (nm:353); the content has no `role`; Radix's arrow-key "FocusGroup" is NOT a roving tabindex (it never touches `tabindex`, never loops, nm:742-780); the viewport-mode content carries NO `data-state` (nm:517-525, 709-719); `NavigationMenuLink active` renders `data-active=""` (nm:421) so shadcn's `data-[active=true]:*` classes never match unless the caller passes `data-active="true"` themselves.

## API

Every part: `class:` goes through `cn` last (caller wins), `**attrs` pass through (`data:` / `aria:` deep-merged, caller attrs are spread AFTER the Radix attrs as in React, so they override them, nm:161-165, 354, 423, 617), string and symbol option values accepted (`orientation: :vertical` == `"vertical"`).

| React | Ruby | Notes |
|---|---|---|
| `NavigationMenu` (tsx:7-29, `NavigationMenuPrimitive.Root`; Radix props nm:47-58) | `Components::V2::NavigationMenu.new(viewport: true, value: nil, default_value: "", delay_duration: 200, skip_delay_duration: 300, orientation: "horizontal", dir: nil, activation_mode: "automatic", class: nil, **attrs) { ... }` | Renders `<nav>`; it is the Stimulus host (`chadcn--navigation-menu`). `viewport:` shadcn prop (default `true`, tsx:10): rendered as `data-viewport="true"\|"false"` and, when true, the Root renders `NavigationMenu::Viewport` itself after the block (tsx:26). `value:` non-nil = controlled (`""` = all closed); `nil` = uncontrolled starting at `default_value` (nm:66-85, `defaultValue ?? ""`). Values are the Item values (Strings). `delay_duration`/`skip_delay_duration` Integers in ms. `orientation:` `"horizontal" \| "vertical"`. `dir:` `"ltr" \| "rtl"`; nil = `Components::V2::Direction` provider value or `"ltr"` (`useDirection`, never `html[dir]`). `activation_mode:` `"automatic" \| "manual"` (nm:24-27, 56; manual disables every hover open/close, nm:129-152). No `as_child:` (shadcn renders children plus the Viewport inside the Root, so a Radix Slot would receive several children and throw). |
| `NavigationMenuList` (tsx:31-45) | `NavigationMenu::List.new(as_child: false, class: nil, **attrs) { ... }` | `<ul>` inside Radix's indicator-track `<div style="position: relative">` (nm:283-284). Attrs/class go on the `ul`, never on the track div. `as_child:` replaces the `ul` (Radix `Primitive.ul`). |
| `NavigationMenuItem` (tsx:47-57) | `NavigationMenu::Item.new(value: nil, as_child: false, class: nil, **attrs) { ... }` | `<li>`. `value:` the item's String value; nil = a generated id (nm:293-294 `useId`). `as_child:` replaces the `li`. |
| `NavigationMenuTrigger` (tsx:63-82) | `NavigationMenu::Trigger.new(disabled: false, class: nil, **attrs) { ... }` | `<button>` (no `type` attribute: Radix `Primitive.button` sets none, nm:346). Class = `cn(NavigationMenu.trigger_style, "group", class)` (tsx:71). No `as_child:` (shadcn appends a text node and the chevron, so a Radix Slot would get several children and throw). `id:` from the caller replaces the generated trigger id (nm:348 then `...triggerProps`) while the content's `aria-labelledby` keeps the generated one (dangling, as in React). |
| `NavigationMenuContent` (tsx:84-98) | `NavigationMenu::Content.new(force_mount: false, as_child: false, class: nil, **attrs) { ... }` | `<div>`. Where it is mounted depends on the viewport (see Structure). `force_mount:` Radix prop (nm:512, 526, 711). `id:` from the caller replaces the generated content id; the trigger's `aria-controls` keeps the generated one. `dir:` from the caller overrides the inherited `dir` (Slot merge, child wins). |
| `NavigationMenuViewport` (tsx:100-120) | `NavigationMenu::Viewport.new(force_mount: false, class: nil, **attrs)` | Normally rendered by the Root (`viewport: true`). Callers may render it explicitly (scenario `viewport__explicit-part`); `class:`/attrs go on the inner Radix viewport div, never on the shadcn wrapper div (tsx:105-107 `cn` with no className). |
| `NavigationMenuLink` (tsx:122-136) | `NavigationMenu::Link.new(active: false, as_child: false, class: nil, **attrs) { ... }` | `<a>` (`Primitive.a`, nm:419). `href:` etc. via attrs. `active: true` renders `data-active=""` and `aria-current="page"` (nm:421-422). `as_child:` false \| tag symbol \| V2 component instance (`Components::V2::Base#render_as_child`, Radix Slot merge: child wins, class plain join, `data-controller` unioned). |
| `NavigationMenuIndicator` (tsx:138-154) | `NavigationMenu::Indicator.new(force_mount: false, class: nil, **attrs)` | Takes no block: shadcn renders its own arrow child (tsx:151). Mounted into the List's track div, wherever it is called (nm:454-457). |
| `navigationMenuTriggerStyle()` (tsx:59-61, cva with no variants) | `Components::V2::NavigationMenu.trigger_style(class: nil)` -> String | Returns the cva base string verbatim (manifest `cva.navigationMenuTriggerStyle.base`), `cn`-merged with `class:` (cva's `class` option). Used by callers on `Link` (demo: `Link.new(as_child: ..., class: NavigationMenu.trigger_style)`). Scenarios pass the literal string as `className` because JSON cannot call functions; both sides then `cn` the same strings. |

Not ported: `ref`; `NavigationMenuSub` (Radix export, not exported by shadcn).

Events (dispatched with `this.dispatch` by the `chadcn--navigation-menu` controller, `bubbles: true`, prefix `chadcn--navigation-menu:`):

| Event | Target | Radix origin | detail | cancelable | default action when not prevented |
|---|---|---|---|---|---|
| `value-change` | nav | `onValueChange` (nm:81; fires only when the value changes) | `{ value }` (`""` when closing) | no | uncontrolled: state changes; controlled: nothing changes |
| `link-select` | the link element | Link `onSelect` (nm:425-434, CustomEvent `navigationMenu.linkSelect`, bubbles, cancelable) | `{}` | yes | closes the root menu (unless `metaKey`), see Behavior |
| `escape-key-down` | content | Content `onEscapeKeyDown` (nm:659-661, dl:96-103) | `{ originalEvent }` | yes | `preventDefault` on the key + close |
| `pointer-down-outside` | content | `onPointerDownOutside` (nm:637-642) | `{ originalEvent }` | yes | close (the port prevents it itself for triggers / viewport as Radix does) |
| `focus-outside` | content | `onFocusOutside` (nm:627-636) | `{ originalEvent }` | yes | close (prevented by Radix unless focus left the nav from inside it) |

Callers listen with `data-action="chadcn--navigation-menu:value-change->foo#bar"` on an ancestor or on the nav.

## Structure

Ids: `base_id` per Root (per-render counter from `Components::V2::Base` ids, React `useId` = `radix-_r_N_`; the runner normalizes by first-seen order); item value = `value:` or a per-render generated id; trigger id `"#{base_id}-trigger-#{value}"`, content id `"#{base_id}-content-#{value}"` (nm:838-845). Server-generated so relations resolve before JS.

Server render, closed, `viewport: true` (DOM order exact; `T1/C1` are the ids above):

```html
<nav aria-label="Main" data-orientation="horizontal" dir="ltr" data-slot="navigation-menu" data-viewport="true"
     class="group/navigation-menu relative flex max-w-max flex-1 items-center justify-center"
     data-controller="chadcn--navigation-menu" data-chadcn--navigation-menu-*-value="...">
  <div style="position: relative;">                       <!-- Radix indicator track, no data-slot, no class (nm:284) -->
    <ul dir="ltr" data-orientation="horizontal" data-slot="navigation-menu-list"
        class="group flex flex-1 list-none items-center justify-center gap-1">
      <li data-slot="navigation-menu-item" class="relative">
        <button id="T1" data-state="closed" aria-expanded="false" data-slot="navigation-menu-trigger"
                class="group inline-flex h-9 ... data-[state=open]:focus:bg-accent group">
          Getting started <svg ... class="lucide lucide-chevron-down relative top-[1px] ml-1 size-3 transition duration-300 group-data-[state=open]:rotate-180" aria-hidden="true">...</svg>
        </button>
        <template data-chadcn--navigation-menu-target="contentTemplate" data-value="...">...Content markup...</template>
      </li>
      <li data-slot="navigation-menu-item" class="relative">
        <a href="#docs" data-slot="navigation-menu-link" class="...link classes merged with trigger_style...">Docs</a>
      </li>
    </ul>
  </div>
  <div class="absolute top-full left-0 isolate z-50 flex justify-center">   <!-- shadcn wrapper (tsx:104-108), always rendered when viewport: true -->
    <template data-chadcn--navigation-menu-target="viewportTemplate">...Viewport markup...</template>
  </div>
</nav>
```

Per part:

- **Root `nav`** (nm:159-166, tsx:15-24): attributes `aria-label="Main"`, `data-orientation`, `dir` (always present, `"ltr"` by default), then caller attrs (`aria-label:` overrides "Main"), `data-slot="navigation-menu"`, `data-viewport="true"|"false"` (React stringifies the boolean on a `data-*` attribute), class. Children: the block, then (when `viewport: true`) the Viewport part.
- **List** (nm:283-284): `div[style="position: relative"]` (indicator track; no data-slot, no class) > `ul` with `dir` (from Radix FocusGroup `Primitive.div dir` slotted onto the ul, nm:747; root list only), `data-orientation`, `data-slot="navigation-menu-list"`, class. The Indicator, when mounted, is the LAST child of the track div (after the `ul`, `ReactDOM.createPortal` into the track, nm:454).
- **Item** `li` (nm:327): only caller attrs, `data-slot="navigation-menu-item"`, class `relative`. No `data-state`, no value attribute.
- **Trigger** `button` (nm:346-389): `id`, `disabled=""` and `data-disabled=""` only when disabled, `data-state="open"|"closed"`, `aria-expanded="true"|"false"`, `aria-controls="C1"` ONLY while open, then caller attrs, `data-slot="navigation-menu-trigger"`, class. Class string is `cn(trigger_style, "group", class)`; tailwind-merge 2.6.1 does not dedupe the non-utility `group`, so the oracle class attribute contains `group` twice (first and after `data-[state=open]:focus:bg-accent`); the Ruby `cn` must produce the same string. Children: the block, then a literal `" "` text node, then `Components::V2::Icon` `chevron-down` with class `relative top-[1px] ml-1 size-3 transition duration-300 group-data-[state=open]:rotate-180` and `aria-hidden="true"` (tsx:73-79; lucide-react prepends `lucide lucide-chevron-down`).
- **Trigger siblings while open** (nm:391-410), inserted by the controller directly after the button, inside the `li`, removed on close:
  1. focus proxy `<span aria-hidden="true" tabindex="0" style="...">` with exactly the VisuallyHidden style object (vh:9-21: `position: absolute; border: 0; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; word-wrap: normal`), set through `element.style` so the browser serializes it like React does;
  2. `<span aria-owns="C1"></span>` ONLY when a Viewport is mounted (`context.viewport &&`, nm:409). With `viewport: false` there is no aria-owns span.
- **Content** (nm:560-663, tsx:89-96): `div` with `id="C1"`, `aria-labelledby="T1"`, `data-motion` (only when non-null: `from-start|from-end|to-start|to-end`), `data-orientation`, `dir` (inherited, FocusGroup nm:747; caller `dir:` wins), `data-state` ONLY in no-viewport mode (nm:529), caller attrs, `data-slot="navigation-menu-content"`, class. `style="pointer-events: none"` only in no-viewport mode while closing (nm:539); otherwise no style attribute (unless the caller passes one). No role, no tabindex.
  - Viewport mode (a Viewport is mounted): the call site renders nothing in React (`ViewportContentMounter` returns null, nm:545-558). The active content is rendered INSIDE the Radix viewport div (nm:709-720). The port keeps the markup in an inert `<template>` at the call site (deviation) and the controller clones it into the viewport.
  - No-viewport mode (`viewport: false` and no explicit Viewport): the content is mounted in place inside the `li`, after the trigger's open siblings (nm:526-543), and only while open (Presence) or with `force_mount: true` (then always mounted, `data-state="closed"`, `style="pointer-events: none"` while closed).
- **Viewport** (nm:673-724, tsx:100-120): shadcn wrapper `div.absolute.top-full.left-0.isolate.z-50.flex.justify-center` (always, no data-slot); inside it, only while any item is open or exiting (Presence `present = forceMount || Boolean(value)`, nm:671), the Radix viewport `div` with `data-state="open"|"closed"`, `data-orientation`, caller attrs, `data-slot="navigation-menu-viewport"`, class, and `style` = `pointer-events: none` while closing (nm:700) plus `--radix-navigation-menu-viewport-width: Wpx; --radix-navigation-menu-viewport-height: Hpx` once measured (nm:683-702; absent before the first measurement). Children: one content div per item that is active (value while open, previous value while closing, nm:686) or exiting (Presence), in content registration order (= DOM order of the Content call sites, a Map keyed by item value, nm:260-265). No `dir` on the viewport.
- **Link** `a` (nm:418-446): `data-active=""` and `aria-current="page"` when `active`, caller attrs, `data-slot="navigation-menu-link"`, class. No tabindex, no role. With `as_child:` the attrs land on the child.
- **Indicator** (nm:450-509, tsx:144-152): mounted only while visible (`Boolean(value)`) or exiting, or always with `force_mount: true`, AND only once a position exists (rendered `null` until measured, nm:484): `div aria-hidden="true" data-state="visible"|"hidden" data-orientation` + caller attrs + `data-slot="navigation-menu-indicator"` + class, `style` horizontal: `position: absolute; left: 0px; width: {offsetWidth}px; transform: translateX({offsetLeft}px); --radix-navigation-menu-indicator-translate-x: {offsetLeft}px`, vertical: `position: absolute; top: 0px; height: {offsetHeight}px; transform: translateY({offsetTop}px); --radix-navigation-menu-indicator-translate-y: {offsetTop}px` (nm:492-506). Use the trigger's `offsetLeft/offsetTop/offsetWidth/offsetHeight` verbatim (NOT `getBoundingClientRect`): with shadcn's `relative` Item, the trigger's offsetParent is the `li`, so offsetLeft is `0` for every trigger, and the oracle shows exactly that. Child: `<div class="relative top-[60%] h-2 w-2 rotate-45 rounded-tl-sm bg-border shadow-md"></div>` (tsx:151). The port keeps the indicator markup in an inert `<template>` at the call site (deviation); the controller mounts it as the last child of the track div.
- **Server vs Stimulus:** the server renders nav, track, ul, items, triggers (with `data-state`/`aria-expanded`/`aria-controls` for the initial value: `value:` or `default_value:`), links, the viewport wrapper and the three template kinds. Stimulus (in `connect()` for an initially open item, then on every change) mounts/unmounts the content, viewport and indicator, the focus proxy and aria-owns spans, sets `data-state`, `aria-expanded`, `aria-controls`, `data-motion`, the viewport size vars, the indicator style, `pointer-events: none` on exiting parts, and the `tabindex`/`data-tabindex` bookkeeping. The React catalog is client-rendered, so the oracle's first observable DOM is the post-effect DOM; the port's post-`connect()` DOM must equal it.

## Behavior

Primitives composed: `dismissable_layer` (one layer per mounted content, `disableOutsidePointerEvents: false`, nm:619), `presence` (viewport, each content, indicator), `collection` (ordered triggers for motion and indicator; ordered focus-group items), `hover_intent` (open/close/skip-delay timers with the Radix constants below), `ids`, `direction`. ResizeObserver + `requestAnimationFrame` measurement (nm:816-832) for the viewport size and indicator position. NOT composed: `focus_scope` (no trap), `scroll_lock`, `hide_others`, `focus_guards`, `positioner`/floating-ui, `roving_focus` (its tabindex swapping does not exist here), `typeahead`, `submenu_grace`.

State: Root `value` (String, `""` = closed). An item is open when `item.value == value` (nm:343, 516). `previous_value` = the last distinct value (`usePrevious`). `is_open_delayed` starts `true` (nm:65).

On every value change (`onChange`, nm:68-82): if the new value is non-empty, clear the skip timer and, when `skip_delay_duration > 0`, set `is_open_delayed = false`; if empty, restart the skip timer (`skip_delay_duration`, default 300ms) that sets `is_open_delayed = true`. Then dispatch `value-change`. Controlled (`value:` given): the same timer logic runs and the event is dispatched, but the DOM keeps the server value.

Timers (Root, nm:86-117), defaults `delay_duration` 200ms, close 150ms (hard-coded, nm:88), `skip_delay_duration` 300ms:
- `start_close_timer`: clear close timer; after 150ms set value `""`.
- `handle_open(v)`: clear close timer; set value `v`.
- `handle_delayed_open(v)`: if `v` is already the open value, clear the close timer; else after `delay_duration` clear the close timer and set value `v`.
- All three timers are cleared on disconnect (nm:111-117).

Pointer (all hover rules only when `activation_mode == "automatic"`, nm:128-153; "mouse" = `event.pointerType === "mouse"`, nm:846-848):

| Element | Event | Rule |
|---|---|---|
| Trigger | `pointerenter` | reset `was_click_close` and the item's `was_escape_close` (nm:356-359) |
| Trigger | `pointermove` (mouse only) | ignored when disabled, `was_click_close`, `was_escape_close` or already handled since the last leave (`has_pointer_move_opened`); else `onTriggerEnter`: clear open timer, then `is_open_delayed ? handle_delayed_open(v) : handle_open(v)`; set `has_pointer_move_opened` (nm:360-368, 128-137) |
| Trigger | `pointerleave` (mouse only) | ignored when disabled; clear open timer, `start_close_timer`, reset `has_pointer_move_opened` (nm:369-376, 138-143) |
| Trigger | `click` (also Enter/Space via the native button) | toggle: value = (value == v ? `""` : v) (nm:154-156); then `was_click_close = <was open before the click>` (nm:377-380), so after a click-close the hover does not reopen it until the pointer re-enters the trigger. A click while hover-opened therefore CLOSES it. |
| Viewport (viewport mode) / Content (no-viewport mode) | `pointerenter` (any pointer) | clear close timer (nm:144-148, 532, 705) |
| Viewport / Content | `pointerleave` (mouse only) | `start_close_timer` (nm:149-153, 533-536, 706) |

Moving trigger -> viewport across the `mt-1.5` gap stays open because the viewport `pointerenter` clears the 150ms close timer. Moving trigger A -> trigger B while open switches immediately (`is_open_delayed` is false). Within 300ms of closing, a new hover opens without delay. `activation_mode: "manual"`: only click/Enter/Space open and close.

Keyboard (FocusGroup, nm:742-780, applies to every Trigger and every Link; the root List is one group, each Content is its own group):

| Key | Where | Rule |
|---|---|---|
| `ArrowDown` (horizontal) / `ArrowRight` (vertical, ltr) / `ArrowLeft` (vertical, rtl) | open Trigger | entry: restore the content's saved tab order, focus the first tabbable in the content, `preventDefault` (nm:381-388, 301-307). Because the trigger handler prevents the event, the focus-group handler does not run (composeEventHandlers checks `defaultPrevented`). |
| `ArrowRight`, `ArrowDown`, `Home` | any group item (closed trigger, link) | next items = group items after the current one (`Home`: all items); `setTimeout(0)` then focus the first that accepts focus; `preventDefault` (nm:762-776). No loop: at the last item nothing moves. In rtl `ArrowRight` is a "previous" key instead. |
| `ArrowLeft` (ltr) / `ArrowRight` (rtl), `ArrowUp`, `End` | any group item | same on the reversed list (`End` = last item). |
| `Enter`, `Space` | Trigger | native button click -> toggle (above). Focus alone never opens. |
| `Tab` (no Alt/Ctrl/Meta) | inside Content | focus the next tabbable inside the content (Shift: previous) and `preventDefault`; if none, focus the item's focus proxy WITHOUT preventing, so the browser then moves on from the proxy (nm:643-658). |
| focus lands on the focus proxy | proxy | if it came from the trigger: content entry at the start; if it came from outside the content: entry at the END (focus last tabbable); if it came from inside the content: nothing (nm:398-406). |
| `Escape` | anywhere (document `keydown` capture, top-most layer only, dl:91-107) | dispatch cancelable `escape-key-down`; set the item's `was_escape_close` (nm:659-661); unless prevented, `preventDefault` + dismiss (below). |

Tab order bookkeeping (observable in the DOM, reproduce exactly): whenever focus moves outside a mounted content (`focus-outside`, nm:627-629) and on dismiss (nm:584), every tabbable candidate of that content (tree walker: not disabled, not `hidden`, not `input[type=hidden]`, `tabIndex >= 0`, nm:781-792) gets `data-tabindex` = its previous `tabindex` attribute or `""` and `tabindex="-1"` (nm:803-814). The next content entry restores `tabindex` to the saved value (so a link that had no tabindex ends up with `tabindex=""`) and leaves `data-tabindex` in place. Hence: Tab from the open trigger -> proxy -> first content link; Tab through the links -> after the last one the proxy, then the browser moves to the next trigger (content links are now `tabindex="-1"` and skipped); Shift+Tab from the next trigger -> proxy -> last content link.

Dismissal (`onDismiss`, nm:620-626 dispatches `navigationMenu.rootContentDismiss` on the content; handled for the root menu by nm:579-590): set value `""` (`onItemDismiss`), apply the tab-order removal, and if focus was inside the content, focus the trigger. Triggers:
- `Escape` (above).
- `pointerdown` outside the content (dl `usePointerDownOutside`, listener attached one `setTimeout(0)` after mount): dispatch `pointer-down-outside`; prevented by Radix when the target is inside any Trigger or inside the root viewport (nm:637-642). So pressing another trigger switches items (click), pressing the viewport padding keeps it open, pressing a top-level Link (e.g. "Docs") or anything else closes.
- Focus moving outside the content (`focusin` on document outside the layer): dispatch `focus-outside`; prevented when focus moved into the nav or came from outside the nav (nm:630-635); so it only closes when focus leaves the nav from inside it (Tab from the last top-level item to an element after the nav).
- Link selection (nm:425-444): on `click` of a Link, dispatch cancelable `link-select` on the link (Radix calls `onSelect` from it); unless prevented and unless `event.metaKey`, dispatch the root-content-dismiss event from the link; it closes the menu only when the link is inside a Content (top-level links have no listener). Runs even if the caller's click handler called `preventDefault` (`checkForDefaultPrevented: false`).

`data-motion` (nm:591-609), computed per content from the ordered trigger values (reversed in rtl), `index = indexOf(value)`, `prev = indexOf(previous_value)`: for the newly selected content, when `index != prev` and `prev != -1`: `from-end` if `index > prev` else `from-start`; for the previously selected content, when `index != -1`: `to-start` if `index > prev` else `to-end`; otherwise `null` (attribute removed); a content that is neither selected nor previously selected keeps its last value. Opening from closed and closing therefore produce no `data-motion`. A remounted content starts with no previous attribute.

Presence (R6): viewport (`data-state=closed` exit: `animate-out zoom-out-95`), contents in the viewport (`data-[motion^=to-]` exit), no-viewport content (`group-data-[viewport=false]/navigation-menu:data-[state=closed]:animate-out ...`), indicator (`data-state=hidden` exit) stay mounted until `animationend`; with no animation they unmount in the same frame. While a content switch animates, the outgoing and incoming contents coexist in the viewport.

Measurement: the viewport observes the active content (`offsetWidth`/`offsetHeight`, ResizeObserver, applied in the next animation frame, nm:687-690); the indicator observes the active trigger and the track (nm:469-483). The active trigger for the indicator is updated only when the value matches an item, so after closing it keeps the last position.

Turbo/cleanup (R10): disconnect clears the three timers, ResizeObservers and rAFs, removes layer and document listeners, removes mounted content/viewport/indicator/proxy spans. A cached page must not restore an open menu.

Not exercised by the runner (G3 controller unit tests instead): `pointerType` touch/pen ignored on move/leave, `metaKey` link click, cancelable events, `skip_delay_duration: 0` edge (`is_open_delayed` stays true), nested layers.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::NavigationMenu` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render NavigationMenu::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::NavigationMenu::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `navigation_menu.list` | `NavigationMenu::List` | `NavigationMenuList` |
| `navigation_menu.item` | `NavigationMenu::Item` | `NavigationMenuItem` |
| `navigation_menu.content` | `NavigationMenu::Content` | `NavigationMenuContent` |
| `navigation_menu.trigger` | `NavigationMenu::Trigger` | `NavigationMenuTrigger` |
| `navigation_menu.link` | `NavigationMenu::Link` | `NavigationMenuLink` |
| `navigation_menu.indicator` | `NavigationMenu::Indicator` | `NavigationMenuIndicator` |
| `navigation_menu.viewport` | `NavigationMenu::Viewport` | `NavigationMenuViewport` |

Names that shadow a Phlex HTML element inside `NavigationMenu`'s OWN `view_template` (use `tag(:link)` there, never the bare method): `link`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Components::V2::Icon` (`chevron-down`, Trigger, tsx:73-79; manifest `icons: ["ChevronDownIcon"]`, lucide-react version of the catalog).
- `Components::V2::Direction` (provider read for `dir: nil`).
- `Components::V2::Base` (`cn`, `merge_attrs`, `render_as_child`, ids). Manifest `registry_dependencies: []`, so scenarios use only NavigationMenu exports and raw `_` elements.

## Deviations

One structural, invisible deviation (`gems/chadcn/dev/port/deviations/navigation-menu.json`), same pattern as Tooltip/HoverCard:

- `NavigationMenu::Content` (call site, inside the `li`), `NavigationMenu::Viewport` (inside the shadcn wrapper div) and `NavigationMenu::Indicator` (call site) emit inert `<template data-chadcn--navigation-menu-target="...">` elements holding their markup while unmounted. Reason: Radix renders nothing for them while closed and creates the nodes on the client (contents inside the viewport via a registry, the indicator via a portal into the List track). The templates have no `data-slot`, no box and their content is not part of the document, so G2 node lists, boxes and a11y are unaffected.

```json
{ "component": "navigation-menu", "reason": "...", "allow_tokens": [], "allow_missing_tokens": [], "api": ["NavigationMenu::Content, ::Viewport and ::Indicator render inert <template data-chadcn--navigation-menu-target> elements (no data-slot) holding their markup while unmounted"] }
```
