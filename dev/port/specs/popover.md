# Popover (shadcn new-york-v4, Radix `Popover`)

Oracle: `gems/phlex-shadcn/dev/port/oracle/src/popover.tsx` (manifest `source_sha` 3f99d3add6c9fa4f), manifest `oracle/manifest/popover.json`.
Behavior source: `gems/phlex-shadcn/dev/react-shadcn-catalog/node_modules/@radix-ui/react-popover/dist/index.mjs` v1.2.0 (cited `pop:<line>`), built on `react-popper` 1.3.8 (`popper:`), `react-dismissable-layer` 1.1.20 (`dl:`), `react-focus-scope` 1.2.0 (`fs:`), `react-focus-guards` 1.1.6 (`fg:`), `react-presence` 1.1.11 (`pr:`), `react-portal` 1.1.18, `react-use-controllable-state` (`ucs:`), `react-remove-scroll` 2.7.2 (+ `react-remove-scroll-bar`, `rsb:`), `aria-hidden` 1.2.6 (`ah:`), all from `radix-ui` 1.7.0; `@floating-ui/react-dom` 2.1.9 / `@floating-ui/dom` 1.8.0; React 19.
Examples: registry `new-york-v4/popover-demo.json`; docs examples `popover-demo`, `popover-basic`, `popover-alignments`, `popover-form`, `popover-rtl` (`apps/v4/examples/radix/*.tsx` on shadcn-ui/ui main; the popover markup is style independent).
Tier: `overlay`. Family: Overlay (floating), same positioning/template pattern as `specs/hover-card.md` and `specs/tooltip.md`, focus/modal rules shared with `specs/dialog.md`.

Note for `radix-dom-contract.md`: shadcn's `PopoverTitle` / `PopoverDescription` are plain `div` / `p` (tsx), NOT `PopoverPrimitive.Title` / `.Description` (pop:306-327), so the Content never gets `aria-labelledby` / an automatic `aria-describedby`, and the title/description get no `id`.

## API

Every part: `class:` goes through `cn` last (caller wins), `**attrs` pass through (`data:` / `aria:` deep-merged), string and symbol option values accepted (`side: :left` == `side: "left"`).

| React | Ruby | Notes |
|---|---|---|
| `Popover` (`PopoverPrimitive.Root`; props `open`, `defaultOpen`, `onOpenChange`, `modal = false`, pop:36-44) | `Components::V2::Popover.new(open: nil, default_open: false, modal: false) { ... }` | Renders no element (data-slot `popover` dropped, manifest `non_rendered_slots`). `open:` true/false = controlled (the controller never changes its own state, only dispatches `open-change`); `nil` = uncontrolled, starts at `default_open` (pop:50-55). Generates a per-render key and the content id and pushes them plus `modal` into the Phlex render context for its parts. |
| `PopoverTrigger` (`PopoverPrimitive.Trigger`, pop:94-114) | `Components::V2::Popover::Trigger.new(as_child: false, class: nil, **attrs) { ... }` | `<button>`. `as_child:` false \| tag symbol \| V2 component instance via `Components::V2::Base#render_as_child` (Radix Slot merge: child wins, class plain join, `data-controller` unioned, `data-action` child first). `disabled: true` renders the native attribute. No default classes (none in the oracle). |
| `PopoverContent` (shadcn wraps `PopoverPrimitive.Portal` + `PopoverPrimitive.Content`; tsx `align = "center"`, `sideOffset = 4`) | `Components::V2::Popover::Content.new(side: "bottom", side_offset: 4, align: "center", align_offset: 0, avoid_collisions: true, collision_boundary: nil, collision_padding: 0, arrow_padding: 0, sticky: "partial", hide_when_detached: false, update_position_strategy: "optimized", force_mount: false, dir: nil, class: nil, **attrs) { ... }` | Popper defaults (popper:101-116): `side` "bottom", `align_offset` 0, `arrow_padding` 0, `avoid_collisions` true, `collision_boundary` `[]` (Ruby `nil`; a CSS selector string or Array of them), `collision_padding` Integer or Hash `{top:, right:, bottom:, left:}` (missing keys 0, popper:125), `sticky` `"partial" \| "always"`, `hide_when_detached` false, `update_position_strategy` `"optimized" \| "always"`. `side_offset` 4 and `align` "center" are the shadcn tsx defaults. `side`: `top\|right\|bottom\|left`; `align`: `start\|center\|end`. `dir:` `"ltr" \| "rtl"` rendered on the popper wrapper AND the content div (popper:227, contentProps). `force_mount:` accepted; no observable effect in shadcn (Portal has no `forceMount`, its Presence unmounts on close, pop:123). Caller `id:` replaces the generated content id on the content (contentProps spread after `id`, pop:281-285) while the trigger's `aria-controls` keeps the generated id (Radix behavior, reproduce). Caller `aria-describedby` passes through unchanged (pop:283, no Radix Description present). `style:` is merged before the five `--radix-popover-*` vars (pop:287-297). |
| `PopoverAnchor` (`PopoverPrimitive.Anchor` -> `PopperPrimitive.Anchor`, pop:80-92, popper:86-94) | `Components::V2::Popover::Anchor.new(as_child: false, class: nil, **attrs) { ... }` | `<div>`. `as_child:` as for Trigger. No default classes. While rendered, the trigger is no longer the positioning reference (pop:113). |
| `PopoverHeader` (`div`) | `Components::V2::Popover::Header.new(class: nil, **attrs) { ... }` | `flex flex-col gap-1 text-sm`. |
| `PopoverTitle` (`div`, typed as `h2` props) | `Components::V2::Popover::Title.new(class: nil, **attrs) { ... }` | `<div>`, `font-medium`. |
| `PopoverDescription` (`p`) | `Components::V2::Popover::Description.new(class: nil, **attrs) { ... }` | `<p>`, `text-muted-foreground`. |

Not ported: `ref`; `onPlaced` (no DOM effect); `PopoverClose`, `PopoverArrow`, `PopoverPortal` (not exported by shadcn; the `Portal` `container` is not exposed); `asChild` on Header/Title/Description (plain elements in React).

Events (dispatched with `this.dispatch` by the `shadcn--popover` controller on its host element, `bubbles: true`, prefix `shadcn--popover:`; Content lives in `body`, so callers listen on the host or with `@document`):

| Event | Radix origin | detail | cancelable | default action when not prevented |
|---|---|---|---|---|
| `open-change` | `onOpenChange` (pop:53, ucs: only when the value changes) | `{ open }` | no | uncontrolled: state changes; controlled: nothing |
| `open-auto-focus` | Content `onOpenAutoFocus` (pop:263, fs:94-103) | `{}` | yes | focus first tabbable non-link in content, else content |
| `close-auto-focus` | Content `onCloseAutoFocus` (pop:166-169 modal, 204-212 non-modal, fs:107-116) | `{}` | yes | focus the trigger (rules in Behavior) |
| `escape-key-down` | `onEscapeKeyDown` (dl:91-100) | `{ originalEvent }` | yes | `preventDefault` on the key + close |
| `pointer-down-outside` | `onPointerDownOutside` (dl:54-58) | `{ originalEvent }` | yes | close |
| `focus-outside` | `onFocusOutside` (dl:79-89) | `{ originalEvent }` | yes | non-modal: close; modal: always prevented after the caller handler (pop:180-184) |
| `interact-outside` | `onInteractOutside` (dl:57, 87) | `{ originalEvent }` | yes | close (non-modal: prevented when the target is inside the trigger, pop:221-226) |

A caller `click` handler on the Trigger that calls `preventDefault()` suppresses the toggle (`composeEventHandlers`, pop:110): the controller's toggle action runs after the caller's and checks `event.defaultPrevented`.

Example (registry popover-demo):

```ruby
render Components::V2::Popover.new do
  render Components::V2::Popover::Trigger.new(as_child: Components::V2::Button.new(variant: "outline")) { "Open popover" }
  render Components::V2::Popover::Content.new(class: "w-80") do
    div(class: "grid gap-4") { ... }
  end
end
```

## Structure

Server render (closed, default):

```html
<button type="button" aria-haspopup="dialog" aria-expanded="false" data-state="closed" data-slot="popover-trigger" data-controller="shadcn--popover" data-action="click->shadcn--popover#toggle" data-shadcn--popover-*-value="...">Open popover</button>
<template data-shadcn--popover-template="<key>"> ...Content markup below... </template>
```

- `popover` (Root) and the Portal: **no element, no data-slot** (manifest `non_rendered_slots`; radix-dom-contract "Parts that render no element").
- `popover-trigger` (Trigger, pop:100-112): `Primitive.button` with, in this order, `type="button"`, `aria-haspopup="dialog"`, `aria-expanded="true|false"`, `aria-controls="<content id>"` ONLY while open (pop:106), `data-state="open|closed"` (pop:107, `getState` pop:351-353), then caller attrs (can override any of them), `data-slot="popover-trigger"`. No `role`, no `id`, no `tabindex`. Without a custom Anchor the trigger is wrapped in `PopperPrimitive.Anchor asChild` (pop:113) and gets `data-radix-popper-side` / `data-radix-popper-align` while the content is placed (popper:83-95, removed on unmount popper:183-189); with an Anchor rendered it gets neither. With `as_child:` the same attributes land on the child (`<a href type="button" aria-haspopup=...>` for an `_a` child; a V2 child keeps its own `data-slot`).
- `popover-anchor` (Anchor): `<div data-slot="popover-anchor">` + caller attrs and children; `data-radix-popper-side` / `data-radix-popper-align` while the content is placed (popper:89-90). It carries `data-shadcn--popover-anchor="<key>"` so the controller finds it (deviation, invisible to the gate).
- Controller host (deviation): the FIRST rendered of Trigger or Content inside one `Popover` block hosts `data-controller="shadcn--popover"` and its values (`open`, `controlled`, `modal`, `content-id`, `template-key` and the Content positioning values `side`, `side-offset`, `align`, `align-offset`, `avoid-collisions`, `collision-boundary`, `collision-padding`, `arrow-padding`, `sticky`, `hide-when-detached`, `update-position-strategy`, `dir`). In the normal order (Trigger before Content) that is the Trigger, consistent with Tooltip/HoverCard/menus. If no Trigger precedes the Content (Anchor-only controlled popover, or Content written first) the Content's `<template>` is the host and a later Trigger carries `data-shadcn--popover-trigger="<key>"` and is bound by the controller directly (Stimulus `data-action` cannot cross siblings).
- Content while closed: nothing in the live DOM (Portal Presence pop:123, Content Presence pop:132). The markup ships in an inert `<template data-shadcn--popover-template="<key>">` at the `Popover::Content` call site (no data-slot, no box; deviation, same pattern as Tooltip/HoverCard). Also used when the first render is open (`default_open: true` / `open: true`): the trigger renders `data-state="open" aria-expanded="true" aria-controls`, and the controller mounts the template in `connect()` (the React catalog also mounts portal content on the client).
- Content while open, appended directly to `document.body` (Portal; no wrapper besides Popper's):

```html
<div data-radix-popper-content-wrapper="" style="position: fixed; left: 0px; top: 0px; transform: translate(Xpx, Ypx); min-width: max-content; z-index: 50; --radix-popper-transform-origin: ...; --radix-popper-available-width: ...px; --radix-popper-available-height: ...px; --radix-popper-anchor-width: ...px; --radix-popper-anchor-height: ...px">
  <div data-side="bottom" data-align="center" data-state="open" role="dialog" id="<content id>" tabindex="-1" data-slot="popover-content"
       class="z-50 w-72 origin-(--radix-popover-content-transform-origin) rounded-md border bg-popover p-4 text-popover-foreground shadow-md outline-hidden data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"
       style="--radix-popover-content-transform-origin: var(--radix-popper-transform-origin); --radix-popover-content-available-width: var(--radix-popper-available-width); --radix-popover-content-available-height: var(--radix-popper-available-height); --radix-popover-trigger-width: var(--radix-popper-anchor-width); --radix-popover-trigger-height: var(--radix-popper-anchor-height);">
    {children}
  </div>
</div>
```

  - Wrapper (popper:204-227): floating-ui `floatingStyles` (strategy `fixed`), `transform: translate(0, -200%)` until positioned, `min-width: max-content`, `z-index` copied from the content's computed z-index (`50`), `--radix-popper-transform-origin` (no arrow), the four `size` vars (popper:156-165), `dir` only when given, `visibility: hidden; pointer-events: none` when `hide_when_detached` and the anchor is hidden.
  - Content div: `data-side` / `data-align` (placed values after shift/flip, popper:241-242), `data-state` (pop:279), `role="dialog"` (pop:280), `id` = generated content id (pop:281, always present, open or closing), `tabindex="-1"` (FocusScope, fs:145), no `aria-labelledby`, `aria-describedby` only when the caller passes it, caller attrs, `data-slot="popover-content"`, `dir` when given, oracle class string + `class:` via `cn`. Inline style: caller `style`, then the five `--radix-popover-*` vars (pop:290-296), `animation: none` until positioned (popper:250), and `pointer-events: auto` while any layer with outside pointer events disabled is open (modal popover, or inside a modal dialog/menu; otherwise no `pointer-events` property, dl:147).
  - Children: only the caller block (no arrow, no close button, no icon, no sr-only text in the oracle).
- `popover-header` `<div class="flex flex-col gap-1 text-sm">`, `popover-title` `<div class="font-medium">`, `popover-description` `<p class="text-muted-foreground">`: pure server render, no ids, no ARIA.
- Focus guards while the content is mounted (modal AND non-modal, `useFocusGuards` pop:255): one `<span data-radix-focus-guard tabindex="0" style="outline: none; opacity: 0; position: fixed; pointer-events: none">` as first and last child of `body`, ref-counted across layers (fg:14-47).
- Modal only, while mounted: every other `body` child gets `aria-hidden="true"` + `data-aria-hidden="true"` (`hideOthers(content)`, pop:144-147, ah:), body `style="pointer-events: none"` (dl:110-115) and scroll lock `data-scroll-locked="1"` plus the injected `body[data-scroll-locked] { overflow: hidden !important; ... margin-right: <gap>px !important }` rule (RemoveScroll, `allowPinchZoom`, shards = content + focus-scope branch nodes, pop:148-156, rsb:), identical to `specs/dialog.md`.
- Server vs Stimulus: the server renders trigger state (`data-state`, `aria-expanded`, `aria-controls` when open), the anchor and the template. Stimulus mounts/unmounts the content in `body`, positions it, toggles `data-state` / `aria-expanded` / `aria-controls`, sets `data-radix-popper-*` on the reference, manages focus guards, focus, hide-others, scroll lock, body pointer-events and all listeners.

## Behavior

Primitives composed: `portal`, `presence`, `positioner`, `dismissable_layer` (`deferPointerDownOutside: true`, `disableOutsidePointerEvents: modal`, pop:165/203/275), `focus_scope` (`loop: true`, `trapped: modal && open`, branch registry, pop:256-264), `focus_guards`, `ids`; modal adds `hide_others` and `scroll_lock`. No hover intent, no timers besides the Radix `setTimeout(0)`s, no roving focus, no typeahead.

States: `closed` <-> `open` on Trigger (`data-state`, `aria-expanded`, `aria-controls`) and Content (`data-state`). Opening one popover does not close another by itself; the other closes through its own outside-pointer rule.

Transitions:

| From | Input | To | Source / notes |
|---|---|---|---|
| closed | Trigger `click` (mouse, or Enter / Space through the native button) | open | `onOpenToggle` (pop:70, 110); no key handlers, the native button click is the contract. Disabled trigger: nothing. |
| open | Trigger `click` | closed | toggle; the deferred outside-pointer dismissal is prevented for targets inside the trigger (non-modal, pop:221-223), so it toggles once. In modal mode body has `pointer-events: none`, so a press on the trigger's area hits `html` and is an outside press (dismiss). |
| open | `Escape` (document `keydown` capture, top-most layer only, dl:91-107) | closed | `escape-key-down` (cancelable), then `preventDefault` + dismiss. |
| open | left-button press outside content | closed | DEFERRED (dl:264-273): `pointerdown` outside arms it, dismissal fires on the following `click` (on whichever element the click lands, e.g. a press outside released inside the content still dismisses); a press that starts inside the content never dismisses (dl:274-277). If an outside handler stops `pointerup/mousedown/mouseup/click` before it reaches `document`, the dismissal is cancelled (dl:212-238). The listener is attached one `setTimeout(0)` after mount (dl:292-294). Dispatch `pointer-down-outside` then `interact-outside`; dismiss unless prevented. |
| open | right / middle button press outside | closed | not deferred (`event.button !== 0`, dl:267-268), dismiss on `pointerdown`. |
| open | focus moves outside (programmatic, or anything except a deferred left press) | non-modal: closed; modal: open | `focus-outside` + `interact-outside` (dl:79-89); suppressed while a left press outside is pending (dl:80-82); non-modal also prevents the focusin case after a pointerdown outside (pop:224-226); modal always prevents (pop:180-184) and the trap pulls focus back to the last focused element in the content (fs:51-66). |

Focus on open (Content mount, fs:89-104): if focus is not already inside, dispatch `open-auto-focus`; unless prevented focus the first tabbable that is NOT an `<a>` (`removeLinks`, fs:266-268) with `preventScroll`, selecting `<input>` text (fs:229-236); if nothing took focus, focus the content itself (`tabindex="-1"`, `outline-hidden`). Same in modal and non-modal.

Tab inside the content (fs:120-144, `loop: true` in BOTH modes): Tab on the last tabbable focuses the first, Shift+Tab on the first focuses the last; with no tabbables and focus on the content, Tab is prevented (focus stays). Links count as tabbable for the edges (`getTabbableEdges` does not remove links). So in non-modal mode keyboard focus also cannot leave by Tab; only modal adds the focusin/focusout trap and the mutation observer (fs:50-88).

Focus on close (Content unmount after Presence exit, then `setTimeout(0)`, fs:105-117): dispatch `close-auto-focus`;
- non-modal (pop:204-212): unless the caller prevented it, focus the trigger only if no outside interaction happened during this open (`hasInteractedOutside`, set by any not-prevented `interact-outside`, INCLUDING a trigger press, pop:213-220), then prevent FocusScope's default; flags reset on every close. Escape -> focus returns to the trigger; outside click -> focus stays where the click put it (body, or the clicked focusable); trigger click -> the trigger already has focus from the press.
- modal (pop:166-169): always prevents FocusScope's default and focuses the trigger, except after a right click or ctrl+left click outside (`isRightClickOutside`, pop:170-178).
- Focus scopes stack: a nested trapped scope pauses the outer one (fs:238-255); the content registers as a focus-scope branch of an enclosing scope (pop:254, fs:168-175) so a parent Dialog's trap does not steal focus from it.

Modal extras while mounted: `hide_others`, `scroll_lock`, body `pointer-events: none` (restored to its previous inline value when the last such layer goes, dl:119-126), content `pointer-events: auto`; the trigger's computed `pointer-events` is therefore `none`.

Controlled: with `open:` the controller never changes `data-state`/mount itself; every request (trigger toggle, Escape, outside dismiss) only dispatches `open-change` with the requested value, and only when it differs from `open` (ucs:).

Positioning (popper:101-190): floating-ui `computePosition` + `autoUpdate` (`animationFrame` only with `update_position_strategy: "always"`), strategy `fixed`, reference = the Anchor when rendered else the Trigger (pop:113), placement `side` + (`-align` unless center). Middleware order: `offset({ mainAxis: side_offset, alignmentAxis: align_offset })`, `shift({ mainAxis: true, crossAxis: false, limiter: limitShift() when sticky "partial" })`, `flip()`, `size()` (CSS vars), `transformOrigin({ arrowWidth: 0, arrowHeight: 0 })`, `hide({ strategy: "referenceHidden" })` only with `hide_when_detached`; shift/flip/size share `{ padding: collision_padding, boundary, altBoundary: boundary.any? }`; shift and flip only when `avoid_collisions`. `data-side` / `data-align` reflect the final placement. floating-ui version must match the catalog (G5_FLOATING_UI_VERSION).

Presence (pr:20-130): on open the content mounts with `data-state="open"`; the enter animation (`animate-in fade-in-0 zoom-in-95` + `slide-in-from-*` by placed side) starts only after the first position (`animation: none` before, popper:250). On close `data-state` flips to `closed` immediately on Trigger and Content (`aria-expanded="false"`, `aria-controls` removed, modal focus trap released at once because `trapped` follows `open`, pop:164; modal body `pointer-events: none` stays until unmount because `disableOutsidePointerEvents` is the constant `true`, pop:165, dl:108-127) and the node stays until `animationend` of the exit animation, then is removed together with focus guards, hide-others and scroll lock; with no animation (`animation-name: none`) it is removed in the same frame (pr:66). Reopening during the exit cancels the removal. `force_mount: true` on Content changes nothing visible (Portal Presence still unmounts).

Turbo/cleanup: `disconnect()` removes the mounted content, releases every primitive (layer, scope, guards, hide-others, scroll lock, body pointer-events), stops `autoUpdate`, removes document listeners and pending `setTimeout`s. A cached page must not restore an open popover or a locked body.

Not expressible in the runner, covered by the browser tests in `test/javascript/popover.test.mjs` (cancelable events and caller `preventDefault`, an outside element that stops the click intercepts the dismissal like Radix, `hide_when_detached`, `update_position_strategy: "always"`, `collision_boundary`) and `test/javascript/nesting.test.mjs` (inside a Dialog: layer stack, Escape and outside clicks); caller `id:` on Content is a render test in `test/components/v2/popover_test.rb`. Run the browser tests with `bin/rails test:javascript`.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Phlex::Shadcn::Popover` MUST `yield self` from `view_template`; `Phlex::Shadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Popover::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Phlex::Shadcn::Popover::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `popover.trigger` | `Popover::Trigger` | `PopoverTrigger` |
| `popover.content` | `Popover::Content` | `PopoverContent` |
| `popover.anchor` | `Popover::Anchor` | `PopoverAnchor` |
| `popover.header` | `Popover::Header` | `PopoverHeader` |
| `popover.title` | `Popover::Title` | `PopoverTitle` |
| `popover.description` | `Popover::Description` | `PopoverDescription` |

Names that shadow a Phlex HTML element inside `Popover`'s OWN `view_template` (use `tag(:header)` there, never the bare method): `header`, `title`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- No `Components::V2` component is rendered by Popover itself (manifest `icons: []`, `text_literals: []`, `registry_dependencies: []`).
- Callers commonly compose `Components::V2::Button` (trigger via `as_child:`), `Components::V2::Input` and `Components::V2::Label` (inside content), as in the demo. Scenarios use raw `_button` / `_input` / `_label` elements for them because the manifest declares no registry dependency (scenario_coverage only allows dependency exports), same choice as the HoverCard/Tooltip plans.
- `Components::V2::Base#render_as_child` (Slot merge), `cn`.

## Deviations

Structural and invisible to the gates (`gems/phlex-shadcn/dev/port/deviations/popover.json`), same shape as Tooltip/HoverCard:

- `Popover::Content` emits an inert `<template data-shadcn--popover-template="<key>">` at its call site holding the content markup until the controller mounts it in `body`. Reason: Radix renders nothing while closed and creates the node on the client in a body portal; the trigger (a `<button>`) cannot contain it. No `data-slot`, no box, not part of the document.
- `Popover::Anchor` carries `data-shadcn--popover-anchor="<key>"`, and a Trigger that is not the controller host carries `data-shadcn--popover-trigger="<key>"`, so the controller can find parts that are not inside its element (React wires them through context). `data-shadcn--*` is ignored by G2.
- When no Trigger precedes the Content in the block, the `<template>` hosts the controller.

```json
{ "component": "popover", "reason": "...", "allow_tokens": [], "allow_missing_tokens": [], "api": ["Popover::Content renders an inert <template data-shadcn--popover-template> (no data-slot) holding the content markup while closed", "..."] }
```
