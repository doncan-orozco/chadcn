# HoverCard (shadcn new-york-v4, Radix `HoverCard`)

Oracle: `dev/port/oracle/src/hover-card.tsx` (manifest `source_sha` 73f59aa759656501), manifest `oracle/manifest/hover-card.json`.
Behavior source: `dev/react-shadcn-catalog/node_modules/@radix-ui/react-hover-card/dist/index.mjs` v1.1.24 (cited `hc:<line>`), built on `react-popper` 1.3.8 (`popper:`), `react-dismissable-layer` 1.1.20 (`dl:`), `react-presence` 1.1.11 (`pr:`), `react-portal` 1.1.18, `react-focus-scope` 1.2.0 (`fs:`, branch registry only), `react-use-controllable-state` (`ucs:`), all from `radix-ui` 1.7.0; `@floating-ui/react-dom` 2.1.9 / `@floating-ui/dom` 1.8.0; React 19.3.0.
Examples: registry `new-york-v4/hover-card-demo.json`; docs examples `hover-card-demo`, `hover-card-sides`, `hover-card-rtl` (`apps/v4/examples/radix/*.tsx` on shadcn-ui/ui main, radix-nova style; the hover-card markup is style independent).
Tier: `overlay`. Family: Overlay (floating), same as Tooltip (keep `hover_intent` / `positioner` / template usage identical to `specs/tooltip.md`).

Note for `radix-dom-contract.md`: its "Popover / HoverCard" row is WRONG for HoverCard. The Radix source gives the HoverCard Trigger NO `aria-haspopup`, `aria-expanded` or `aria-controls` (hc:86-98) and the Content NO `role` and no `id` (hc:181-222, `PopperContent` is a plain `div`, popper:237-253). The Trigger is an `<a>`, not a `<button>` (hc:87 `Primitive.a`).

## API

Every part: `class:` goes through `cn` last (caller wins), `**attrs` pass through (`data:` / `aria:` deep-merged), string and symbol option values accepted (`side: :left` == `side: "left"`).

| React | Ruby | Notes |
|---|---|---|
| `HoverCard` (`HoverCardPrimitive.Root`; props `open`, `defaultOpen`, `onOpenChange`, `openDelay = 700`, `closeDelay = 300`, hc:27-35) | `Chadcn::HoverCard.new(open: nil, default_open: false, open_delay: 700, close_delay: 300) { ... }` | Renders no element (data-slot `hover-card` is dropped by Radix, manifest `non_rendered_slots`). `open:` true/false = controlled (the controller never changes its own state, only dispatches `open-change`); `nil` = uncontrolled, starts at `default_open` (hc:41-46). Pushes its options into the Phlex render context for its Trigger/Content. Delays are Integers (ms). |
| `HoverCardTrigger` (`HoverCardPrimitive.Trigger`, hc:80-100) | `Chadcn::HoverCard::Trigger.new(as_child: false, class: nil, **attrs) { ... }` | `<a>`. `as_child:` false \| tag symbol \| Chadcn component instance via `Chadcn::Base#render_as_child` (Radix Slot merge: child wins, class plain join, `data-controller` unioned). `href:`, `id:`, `aria-*`, `data-*` pass through. No default classes (none in the oracle). |
| `HoverCardContent` (shadcn wraps `HoverCardPrimitive.Portal` + `HoverCardPrimitive.Content`; tsx `align = "center"`, `sideOffset = 4`) | `Chadcn::HoverCard::Content.new(side: "bottom", side_offset: 4, align: "center", align_offset: 0, avoid_collisions: true, collision_boundary: nil, collision_padding: 0, arrow_padding: 0, sticky: "partial", hide_when_detached: false, update_position_strategy: "optimized", force_mount: false, dir: nil, class: nil, **attrs) { ... }` | Defaults: `side` "bottom", `align_offset` 0, `arrow_padding` 0, `avoid_collisions` true, `collision_boundary` `[]` (Ruby `nil`), `collision_padding` 0 (Integer or Hash `{top:, right:, bottom:, left:}`, missing keys 0, popper:125), `sticky` `"partial" \| "always"`, `hide_when_detached` false, `update_position_strategy` `"optimized" \| "always"` (popper:101-116). `side_offset` 4 and `align` "center" are the shadcn tsx defaults. `side`: `top\|right\|bottom\|left`; `align`: `start\|center\|end`. `dir:` `"ltr" \| "rtl"` is rendered on BOTH the popper wrapper and the content div (popper:227 `dir: props.dir`, and it stays in `contentProps`). `force_mount:` accepted; it has no observable effect in shadcn because the Portal (no `forceMount`) still unmounts when closed (hc:108, see Behavior). `HoverCardPrimitive.Portal`'s `container` is not exposed by shadcn and is not ported. |

Not ported: `ref`; `HoverCardArrow` (not exported by shadcn); `HoverCardPortal` as a separate part (shadcn's `HoverCardContent` always wraps it; its slot `hover-card-portal` never reaches the DOM).

Events (dispatched with `this.dispatch` by the `chadcn--hover-card` controller on the trigger element, `bubbles: true`, prefix `chadcn--hover-card:`):

| Event | Radix origin | detail | cancelable | default action when not prevented |
|---|---|---|---|---|
| `open-change` | `onOpenChange` (hc:44, ucs: fires only when the value changes) | `{ open }` | no | uncontrolled: state changes; controlled: nothing |
| `escape-key-down` | Content `onEscapeKeyDown` (hc:187, dl:91-100) | `{ originalEvent }` | yes | `preventDefault` on the key + close |
| `pointer-down-outside` | `onPointerDownOutside` (hc:188, dl:54-58) | `{ originalEvent }` | yes | close |
| `focus-outside` | `onFocusOutside` (hc:189-191, dl:79-89) | `{ originalEvent }` | yes | none: HoverCard always prevents it after the caller's handler, so focus leaving never dismisses |
| `interact-outside` | `onInteractOutside` (hc:186, dl:57 and 87) | `{ originalEvent }` | yes | close (pointer case); focus case is prevented as above |

Example (registry hover-card-demo):

```ruby
render Chadcn::HoverCard.new do
  render Chadcn::HoverCard::Trigger.new(as_child: Chadcn::Button.new(variant: "link")) { "@nextjs" }
  render Chadcn::HoverCard::Content.new(class: "w-80") do
    div(class: "flex justify-between gap-4") { ... }
  end
end
```

## Structure

Server render (closed, default):

```html
<a data-state="closed" data-slot="hover-card-trigger" data-controller="chadcn--hover-card" data-chadcn--hover-card-*-value="...">Hover</a>
<template data-chadcn--hover-card-template="<key>"> ...Content markup below... </template>
```

- `hover-card` (Root) and `hover-card-portal` (Portal): **no element, no data-slot** (manifest `non_rendered_slots`; radix-dom-contract "Parts that render no element").
- `hover-card-trigger` (Trigger, hc:86-98): `Primitive.a` wrapped in `PopperPrimitive.Anchor asChild`. Attributes: `data-state` = `open | closed` (hc:89), then caller attrs (can override), `data-slot="hover-card-trigger"`. No `href` unless the caller passes one (so a bare trigger is NOT focusable), no `type`, no `role`, no `aria-*`, no `tabindex`, no `id`. While the content is mounted and placed, Popper Anchor adds `data-radix-popper-side` / `data-radix-popper-align` with the placed side/align (popper:83-95), removed again when the content unmounts (popper:183-189 `setPlacementState(undefined)`). With `as_child:` the same attributes land on the child element (`<button data-state="closed" data-slot="hover-card-trigger">` for a `_button` child; a Chadcn child keeps its own `data-slot`). The trigger is the Stimulus host (`data-controller="chadcn--hover-card"`) with values `open`, `controlled`, `open-delay`, `close-delay`, `template-key`, and the Content positioning values (`side`, `side-offset`, `align`, `align-offset`, `avoid-collisions`, `collision-padding`, `arrow-padding`, `sticky`, `hide-when-detached`, `update-position-strategy`, `dir`).
- Content while closed: nothing in the live DOM (Portal Presence `present = context.open`, hc:108; Content Presence hc:117). The port renders the content markup inside an inert `<template data-chadcn--hover-card-template="<key>">` emitted at the `HoverCard::Content` call site (no data-slot, no box; deviation, same pattern as Tooltip). `<key>` is a per-render counter (Radix renders no id anywhere in HoverCard, so no id is rendered on the content).
- Content while open, appended directly to `document.body` (Portal; no wrapper besides Popper's):

```html
<div data-radix-popper-content-wrapper="" style="position: fixed; left: 0px; top: 0px; transform: translate(Xpx, Ypx); min-width: max-content; z-index: 50; --radix-popper-transform-origin: ...; --radix-popper-available-width: ...px; --radix-popper-available-height: ...px; --radix-popper-anchor-width: ...px; --radix-popper-anchor-height: ...px">
  <div data-side="bottom" data-align="center" data-state="open" data-slot="hover-card-content"
       class="z-50 w-64 origin-(--radix-hover-card-content-transform-origin) rounded-md border bg-popover p-4 text-popover-foreground shadow-md outline-hidden data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"
       style="--radix-hover-card-content-transform-origin: var(--radix-popper-transform-origin); --radix-hover-card-content-available-width: var(--radix-popper-available-width); --radix-hover-card-content-available-height: var(--radix-popper-available-height); --radix-hover-card-trigger-width: var(--radix-popper-anchor-width); --radix-hover-card-trigger-height: var(--radix-popper-anchor-height);">
    {children}
  </div>
</div>
```

  - Wrapper (popper:206-228): floating-ui `floatingStyles` (strategy `fixed`), `transform: translate(0, -200%)` until positioned, `min-width: max-content`, `z-index` copied from the content's computed z-index (`50` from `z-50`), `--radix-popper-transform-origin` from the transformOrigin middleware (no arrow, so arrow size 0), the `size` middleware writes the four `--radix-popper-available-*/anchor-*` vars on the wrapper (popper:157-164). `dir` attribute only when `dir:` is given. `visibility: hidden; pointer-events: none` when `hide_when_detached` and the anchor is hidden.
  - Content div (popper:237-253, hc:120, hc:194-219): attribute order `data-side`, `data-align` (placed values after flip/shift), `data-state` (`open | closed`), caller attrs, `data-slot="hover-card-content"`, `dir` when given, oracle class string + `class:` through `cn`. Inline style: caller `style`, `user-select: text; -webkit-user-select: text` only while a pointer-down selection is in progress (hc:206-210), the five `--radix-hover-card-*` vars (hc:212-218), and `animation: none` until positioned (popper:250). No `role`, no `id`, no `tabindex`, no `aria-*`.
  - Every tabbable descendant of the content (`tabIndex >= 0`) gets `tabindex="-1"` (hc:175-180, `getTabbableNodes` hc:236-245); Radix reruns this after every render of the content, the port runs it on mount and on every `data-state` change.
  - Children: only the caller block (no arrow, no close button, no icon, no sr-only text in the oracle).
- Server vs Stimulus: the server renders the trigger with `data-state="closed"`, or `data-state="open"` when `open: true` / `default_open: true`, plus the template. Stimulus mounts/unmounts the content in `body`, positions it, toggles `data-state` on trigger and content, sets/removes `data-radix-popper-*` on the trigger, the body `user-select` while selecting, and runs all timers and listeners.

## Behavior

Primitives composed: `hover_intent` (open/close delay timers, no provider/skip-delay for HoverCard), `positioner`, `presence`, `portal`, `dismissable_layer` (`disableOutsidePointerEvents: false`, `deferPointerDownOutside: false`, hc:185), `focus_scope` (branch registration only, `useFocusScopeBranch`, hc:143). No focus trap, no focus move on open/close, no scroll lock, no hide-others, no focus guards, no grace polygon, no global "one open at a time" event (unlike Tooltip).

States: `closed` <-> `open` (`data-state` on trigger and content, hc:89, hc:120). Close keeps the content mounted until the exit animation (`data-[state=closed]:animate-out fade-out-0 zoom-out-95`) ends (Presence, pr:), then removes the wrapper; with no animation it unmounts in the same frame. Opening a second hover card does NOT close the first.

Timers (Root, hc:47-63):
- `onOpen` = clear the close timer; start the open timer `open_delay` (default 700ms) that sets `open = true`. Called again while open it is harmless (sets true again, no event because the value does not change, ucs:).
- `onClose` = clear the open timer; unless `hasSelection` or `isPointerDownOnContent`, start the close timer `close_delay` (default 300ms) that sets `open = false`.
- `onDismiss` = set `open = false` immediately (no delay).
- Both timers cleared on disconnect (hc:58-63).

Pointer and focus (trigger hc:92-96, content hc:122-123):

| Element | Event | Rule |
|---|---|---|
| Trigger | `pointerenter` (ignored when `pointerType === "touch"`, `excludeTouch` hc:232-234) | `onOpen` |
| Trigger | `pointerleave` (not touch) | `onClose` |
| Trigger | `focus` (any source, including mouse-down focus of an `href` anchor) | `onOpen` (delayed like hover) |
| Trigger | `blur` | `onClose` |
| Trigger | `touchstart` | `preventDefault()`; React 19 registers `touchstart` as a passive listener, so this is a no-op in browsers. The port registers a passive listener too (never a non-passive one). |
| Content | `pointerenter` (not touch) | `onOpen` (cancels a pending close, so moving trigger -> content keeps it open) |
| Content | `pointerleave` (not touch) | `onClose` |
| Content | `pointerdown` | if inside the content: `containSelection = true` (body `user-select: none` + `-webkit-user-select: none`, original value saved; content `user-select: text`); `hasSelection = false`; `isPointerDownOnContent = true` (hc:198-204, 145-156) |
| document | `pointerup` (while content mounted) | `containSelection = false` (restore body), `isPointerDownOnContent = false`, then in a `setTimeout(0)`: if `document.getSelection().toString() !== ""` set `hasSelection = true` (hc:157-174). While `hasSelection` is true, leaving trigger/content never closes; only Escape / outside pointerdown do. Both flags reset when the content unmounts. |

Dismissal (DismissableLayer, hc:181-192):
- `Escape` (document `keydown` capture, only the top-most layer, dl:91-107): dispatch cancelable `escape-key-down`; unless prevented, `preventDefault` the key event and dismiss. With two cards open, Escape closes the most recently mounted one first.
- `pointerdown` outside the content (listener attached one `setTimeout(0)` after mount, dl:292-294; the trigger counts as outside): cancelable `pointer-down-outside` then `interact-outside`, then dismiss immediately. A mouse click on an `href` trigger therefore closes the card, and the focus that follows re-opens it after `open_delay`. A bare `<a>` trigger (no `href`) is not focusable, so it stays closed after the click.
- Focus moving outside: `focus-outside` / `interact-outside` dispatched, then always prevented (hc:189-191): never dismisses. Only the trigger `blur` (delayed close) closes on focus change.
- Layer nesting: a hover card inside another layer (dialog, menu) is a child layer; pointerdown inside the hover content does not dismiss the parent (React tree semantics). The content registers as a focus-scope branch (fs:33-38, 168-175) so a trapped parent scope (Dialog) does not pull focus back when focus lands inside it.

Keyboard: no roving, no key handlers besides Escape. `Tab` moves focus normally; focus never moves into the content automatically and is never restored; content tabbables are `tabindex="-1"`, so Tab from the trigger skips them.

Controlled: with `open:` the controller never changes `data-state`/mount itself; every open/close request (timer fire, dismiss) only dispatches `open-change` with the requested value, and only when it differs from `open` (ucs: `value2 !== prop`).

Positioning (popper:101-190): floating-ui `computePosition` + `autoUpdate` (`animationFrame` only with `update_position_strategy: "always"`), strategy `fixed`, placement `side` + (`-align` unless center). Middleware in order: `offset({ mainAxis: side_offset + 0 (no arrow), alignmentAxis: align_offset })`, `shift({ mainAxis: true, crossAxis: false, limiter: limitShift() when sticky "partial" })`, `flip()`, `size()` (CSS vars), `transformOrigin({ arrowWidth: 0, arrowHeight: 0 })`, `hide({ strategy: "referenceHidden" })` only with `hide_when_detached` (its boundary is the explicit `collision_boundary` or floating-ui's default clipping ancestors, popper:169-179); shift/flip/size share `{ padding: collision_padding, boundary, altBoundary: boundary.any? }` (popper:125-132); shift and flip only when `avoid_collisions`. `data-side` / `data-align` reflect the final placement. floating-ui version must match the catalog (G5_FLOATING_UI_VERSION).

Presence: the enter animation (`data-[state=open]:animate-in fade-in-0 zoom-in-95` + `slide-in-from-*` by placed side) starts only after the first position (`animation: none` before, popper:250). Exit waits for `animationend` on the content with `data-state="closed"`. `force_mount: true` on Content changes nothing visible: the shadcn Portal has no `forceMount`, so its Presence (hc:108) still unmounts the subtree after the exit animation.

Turbo/cleanup: disconnect clears both timers, removes the mounted content, restores body `user-select`, removes document listeners (`pointerup`, layer listeners), stops `autoUpdate`, unregisters the focus-scope branch. A cached page must not restore an open card.

Scenario notes (parity harness, not component behavior): `click-trigger-href__reopens-on-focus` passes `data-turbo="false"` on the `href="#profile"` trigger (a forwarded attr, rendered identically by React and Phlex). Without it Turbo intercepts the click on the Phlex harness page as a visit (`turbo:before-visit` for `...#profile`), re-renders the body, the controller reconnects and focus falls to `body`, so the focus re-open could not be observed; React has no Turbo. Hover steps that start a short timer (`open_delay`/`close_delay` 0/10/100 in `open-delay-0__close-delay-0`, `open-delay-100__close-delay-100`, `example__hover-card-demo-docs`, `example__hover-card-sides`, `example__hover-card-rtl`) are `"snapshot": false` and are compared after a `wait` that ends well past the delay (delay + ~300 ms), because a snapshot taken right after the hover races the timer on both sides. Steps under the 700/300 ms defaults keep their immediate snapshots (the pre-delay state is stable there).

Not expressible in the runner, covered by the browser tests in `test/javascript/hover_card.test.mjs` (`pointerType === "touch"` ignored, `touchstart` not default-prevented, cancelable `escape-key-down` / `pointer-down-outside` / `interact-outside`, `open-change`, `hide_when_detached`, `update_position_strategy: "always"`, `collision_boundary`) and `test/javascript/nesting.test.mjs` (inside a Dialog: layer stack). Run them with `bin/rails test:javascript`.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::HoverCard` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render HoverCard::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::HoverCard::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `hover_card.trigger` | `HoverCard::Trigger` | `HoverCardTrigger` |
| `hover_card.content` | `HoverCard::Content` | `HoverCardContent` |


Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- No `Chadcn` component is rendered by HoverCard itself (manifest `icons: []`, `text_literals: []`, `registry_dependencies: []`).
- Callers commonly compose `Chadcn::Button` (trigger via `as_child:`) and `Chadcn::Avatar` (inside content), as in the demo. Scenarios use raw `_button` / `_span` elements for them because the manifest declares no registry dependency (scenario_coverage only allows dependency exports), same choice as the Tooltip plan; the remote avatar image is also left out to keep snapshots deterministic.
- `Chadcn::Base#render_as_child` (Slot merge), `cn`.

## Deviations

One structural, invisible deviation (`dev/port/deviations/hover-card.json`), identical in shape to Tooltip's:

- `HoverCard::Content` emits an inert `<template data-chadcn--hover-card-template="<key>">` at its call site that carries the content markup until the controller mounts it in `body`. Reason: Radix renders nothing while closed and creates the node on the client in a body portal; the server must ship the markup somewhere and the trigger (the controller host, an `<a>`) cannot contain it. The template has no `data-slot`, generates no box, and its content is not in the document, so G2 node lists, boxes and a11y are unaffected.

```json
{ "component": "hover-card", "reason": "...", "allow_tokens": [], "allow_missing_tokens": [], "api": ["HoverCard::Content renders an inert <template data-chadcn--hover-card-template> (no data-slot) holding the content markup while closed"] }
```
